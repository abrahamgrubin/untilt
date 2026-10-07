import { Router } from "express";
import type { AuthedRequest } from "../middleware/auth.js";
import { requireAuth } from "../middleware/auth.js";
import { z } from "zod";
import { checkInCard, generateInsight, insightSnapshotSchema, isPlausibleLocalDate } from "../ai/insight.js";
import { CRISIS_RESOURCES } from "../ai/crisisResources.js";
import { ensureUser } from "../db/repositories/users.js";
import { getMemoryProfile } from "../db/repositories/memoryProfile.js";
import { hasRecentCrisisEvent } from "../db/repositories/crisisEvents.js";
import { getDailyInsight, saveDailyInsight, type StoredInsight } from "../db/repositories/dailyInsights.js";

export const insightRouter = Router();

/** How long after a detected crisis the Today card stays a fixed check-in. */
const CRISIS_CHECK_IN_WINDOW_HOURS = 72;

insightRouter.use(requireAuth);
insightRouter.use(async (req: AuthedRequest, res, next) => {
  try {
    if (!(await ensureUser(req.userId!))) {
      // Recently deleted account whose token hasn't expired yet.
      res.status(401).json({ error: "account_deleted" });
      return;
    }
    next();
  } catch (err) {
    next(err);
  }
});

/**
 * Check-in cards also carry the structured crisis resources (with `tel:`
 * links), so the app can render tap-to-call rows instead of plain text,
 * matching the chat's crisis response. Same single source as the chat:
 * ai/crisisResources.ts.
 */
function toResponse(localDate: string, insight: StoredInsight) {
  return {
    localDate,
    kind: insight.kind,
    ...insight.card,
    ...(insight.kind === "check_in" ? { resources: CRISIS_RESOURCES } : {}),
  };
}

// POST /insight: returns today's Compass insight card, generating it on the
// first request of the user's day. POST rather than GET because the app
// sends its on-device activity snapshot in the body.
insightRouter.post("/", async (req: AuthedRequest, res, next) => {
  const parsed = insightSnapshotSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });
    return;
  }
  const snapshot = parsed.data;
  const userId = req.userId!;

  try {
    const existing = await getDailyInsight(userId, snapshot.localDate);
    if (existing) {
      res.status(200).json(toResponse(snapshot.localDate, existing));
      return;
    }

    if (await hasRecentCrisisEvent(userId, CRISIS_CHECK_IN_WINDOW_HOURS)) {
      const saved = await saveDailyInsight(userId, snapshot.localDate, { kind: "check_in", card: checkInCard() });
      req.log.info({ event: "insight_served", kind: saved.kind }, "daily insight served");
      res.status(200).json(toResponse(snapshot.localDate, saved));
      return;
    }

    const profile = await getMemoryProfile(userId);
    let card;
    try {
      card = await generateInsight(snapshot, profile);
    } catch (err) {
      req.log.error({ err }, "insight generation failed");
    }

    if (!card) {
      // Not stored, so the next open can try again. The app shows its own
      // generic card meanwhile. Nothing about the content is logged.
      req.log.warn({ event: "insight_unavailable" }, "no valid insight generated");
      res.status(503).json({ error: "insight_unavailable" });
      return;
    }

    const saved = await saveDailyInsight(userId, snapshot.localDate, { kind: "insight", card });
    req.log.info({ event: "insight_served", kind: saved.kind }, "daily insight served");
    res.status(200).json(toResponse(snapshot.localDate, saved));
  } catch (err) {
    next(err);
  }
});

const checkInRequestSchema = z.object({
  localDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .refine(isPlausibleLocalDate, "localDate must be within one day of today"),
});

// POST /insight/check-in: only the fixed post-crisis check-in card, for users
// who have Compass (and so the AI insight) turned off. It never calls a
// model or reads the memory profile: a check-in with tap-to-call helplines
// shouldn't depend on AI consent. 204 when there's no check-in to show.
insightRouter.post("/check-in", async (req: AuthedRequest, res, next) => {
  const parsed = checkInRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_body", details: parsed.error.flatten() });
    return;
  }
  const { localDate } = parsed.data;
  const userId = req.userId!;

  try {
    const existing = await getDailyInsight(userId, localDate);
    if (existing) {
      // An AI insight generated earlier today isn't shown with Compass off.
      if (existing.kind === "check_in") {
        res.status(200).json(toResponse(localDate, existing));
      } else {
        res.status(204).send();
      }
      return;
    }

    if (await hasRecentCrisisEvent(userId, CRISIS_CHECK_IN_WINDOW_HOURS)) {
      const saved = await saveDailyInsight(userId, localDate, { kind: "check_in", card: checkInCard() });
      req.log.info({ event: "insight_served", kind: saved.kind }, "check-in served");
      res.status(200).json(toResponse(localDate, saved));
      return;
    }

    res.status(204).send();
  } catch (err) {
    next(err);
  }
});
