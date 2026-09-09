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
