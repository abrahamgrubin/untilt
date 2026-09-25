import { Router } from "express";
import { z } from "zod";
import type { AuthedRequest } from "../middleware/auth.js";
import { requireAuth } from "../middleware/auth.js";
import { checkCrisis } from "../ai/crisisDetection.js";
import { CRISIS_RESOURCES, CRISIS_RESPONSE_MESSAGE } from "../ai/crisisResources.js";
import { streamChat } from "../ai/claude.js";
import { MODE_CONFIG } from "../ai/modes.js";
import { buildSystemBlocks, LISTENING_WRAP_UP_NUDGE, type CompassMode } from "../ai/prompts.js";
import { appendTurn, createSession, endSession, getSession } from "../db/repositories/sessions.js";
import { ensureUser } from "../db/repositories/users.js";
import { recordCrisisEvent } from "../db/repositories/crisisEvents.js";
import { enqueueSessionSummarization } from "../jobs/queue.js";

export const sessionRouter = Router();

sessionRouter.use(requireAuth);
// Lazily ensures a local `users` row exists for the authenticated Cognito
// subject, so every route below can rely on the foreign key being valid.
sessionRouter.use(async (req: AuthedRequest, res, next) => {
  try {
    await ensureUser(req.userId!);
    next();
  } catch (err) {
    next(err);
  }
});

sessionRouter.get("/me", (req: AuthedRequest, res) => {
  res.status(200).json({ userId: req.userId });
});

const startSchema = z.object({
  mode: z.enum(["urge_surfing", "journaling", "listening"]),
});

sessionRouter.post("/", async (req: AuthedRequest, res, next) => {
  const parsed = startSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });
    return;
  }
  try {
    const session = await createSession(req.userId!, parsed.data.mode as CompassMode);
    res.status(201).json({ sessionId: session.id, mode: session.mode });
  } catch (err) {
    next(err);
  }
});

const messageSchema = z.object({
  message: z.string().min(1).max(4000),
});

sessionRouter.post("/:id/message", async (req: AuthedRequest, res, next) => {
  const parsed = messageSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });
    return;
  }
  const { message } = parsed.data;

  let session;
  try {
    session = await getSession(req.params.id, req.userId!);
  } catch (err) {
    next(err);
    return;
  }
  if (!session) {
    res.status(404).json({ error: "session_not_found" });
    return;
  }

  let crisis;
  try {
    crisis = await checkCrisis(message, session.mode);
  } catch (err) {
    // checkCrisis is written to fail toward isCrisis: true internally, so
    // reaching here means something outside that (a bug, an unexpected
    // throw) happened. Still fail toward safety rather than falling through
    // to a normal chat reply for a message we couldn't screen.
    req.log.error({ err, sessionId: session.id }, "crisis check threw unexpectedly");
    crisis = { isCrisis: true as const, source: "llm" as const, classifierFailed: true };
  }

  if (crisis.isCrisis) {
    req.log.warn(
      {
        event: "crisis_detected",
        source: crisis.source,
        classifierFailed: crisis.classifierFailed ?? false,
        sessionId: session.id,
        userId: req.userId,
      },
      "crisis signal detected"
    );
    // Send the crisis response first — the user getting CRISIS_RESPONSE_MESSAGE
    // and the resource numbers must never depend on the audit-log DB write
    // succeeding. recordCrisisEvent is best-effort from here: a failure is
    // logged but does not block or delay the response the user needs.
    res.status(200).json({
      type: "crisis",
      message: CRISIS_RESPONSE_MESSAGE,
      resources: CRISIS_RESOURCES,
    });
    try {
      // Durable audit row (crisis_events table) in addition to the log line
      // above — makes the Section 10 "crisis-resource surfacing rate" metric
      // directly queryable rather than only log-mined.
      await recordCrisisEvent(req.userId!, session.id, crisis.source!);
    } catch (err) {
      req.log.error({ err, sessionId: session.id }, "failed to record crisis event (response already sent)");
    }
    return;
  }

  const config = MODE_CONFIG[session.mode];
  const approachingCap = config.turnCap !== null && session.turnCount + 1 >= config.turnCap;

  const messages = [...session.history, { role: "user" as const, content: message }];
  if (approachingCap) {
    messages.push({ role: "user" as const, content: LISTENING_WRAP_UP_NUDGE });
  }

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();

  try {
    const fullText = await streamChat({
      model: config.model,
      system: buildSystemBlocks(session.mode),
      messages,
      maxTokens: config.maxTokens,
      onToken: (token) => {
        res.write(`data: ${JSON.stringify({ token })}\n\n`);
      },
    });

    await appendTurn(session, message, fullText);
    res.write(`event: done\ndata: ${JSON.stringify({ turnCount: session.turnCount })}\n\n`);
    res.end();
  } catch (err) {
    req.log.error({ err, sessionId: session.id }, "claude stream failed");
    res.write(`event: error\ndata: ${JSON.stringify({ error: "generation_failed" })}\n\n`);
    res.end();
  }
});

// Ends a session and kicks off the (currently in-process, step-4-will-be-SQS)
// memory-profile summarization job — off the request path, response
// doesn't wait on it.
sessionRouter.post("/:id/end", async (req: AuthedRequest, res, next) => {
  try {
    const session = await endSession(req.params.id, req.userId!);
    if (!session) {
      res.status(404).json({ error: "session_not_found" });
      return;
    }
    enqueueSessionSummarization(session.id, req.userId!);
    res.status(200).json({ ended: true });
  } catch (err) {
    next(err);
  }
});
