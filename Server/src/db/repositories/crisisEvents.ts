import { pool } from "../pool.js";
import type { CrisisSource } from "../../ai/crisisDetection.js";

export async function recordCrisisEvent(
  userId: string,
  sessionId: string | undefined,
  source: Exclude<CrisisSource, null>
): Promise<void> {
  await pool.query(
    `INSERT INTO crisis_events (user_id, session_id, source) VALUES ($1, $2, $3)`,
    [userId, sessionId ?? null, source]
  );
}

/**
 * True if a crisis was detected for this user within the last `hours`.
 * Used by the Today insight (routes/insight.ts) to skip generated coaching
 * copy right after a crisis and show a gentle, fixed check-in instead.
 */
export async function hasRecentCrisisEvent(userId: string, hours: number): Promise<boolean> {
  const { rows } = await pool.query<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM crisis_events
       WHERE user_id = $1 AND created_at > now() - make_interval(hours => $2)
     ) AS exists`,
    [userId, hours]
  );
  return rows[0]?.exists ?? false;
}
