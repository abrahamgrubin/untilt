import { Router } from "express";
import type { AuthedRequest } from "../middleware/auth.js";
import { requireAuth } from "../middleware/auth.js";
import { checkInCard, generateInsight, insightSnapshotSchema } from "../ai/insight.js";
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
    await ensureUser(req.userId!);
    next();
  } catch (err) {
    next(err);
  }
});

function toResponse(localDate: string, insight: StoredInsight) {
  return { localDate, kind: insight.kind, ...insight.card };
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
