import { pool } from "../pool.js";
import type { InsightCard, InsightKind } from "../../ai/insight.js";

export interface StoredInsight {
  kind: InsightKind;
  card: InsightCard;
}

export async function getDailyInsight(userId: string, localDate: string): Promise<StoredInsight | undefined> {
  const { rows } = await pool.query<{ kind: InsightKind; content: InsightCard }>(
    `SELECT kind, content FROM daily_insights WHERE user_id = $1 AND local_date = $2`,
    [userId, localDate]
  );
  const row = rows[0];
  return row ? { kind: row.kind, card: row.content } : undefined;
}

/**
 * Inserts today's insight. If two requests race (e.g. the app opened on two
 * devices at once), the first insert wins and both callers get that row back,
 * so a user never sees two different "today's insight" cards.
 */
export async function saveDailyInsight(
  userId: string,
  localDate: string,
  insight: StoredInsight
): Promise<StoredInsight> {
  await pool.query(
    `INSERT INTO daily_insights (user_id, local_date, kind, content) VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, local_date) DO NOTHING`,
    [userId, localDate, insight.kind, JSON.stringify(insight.card)]
  );
  return (await getDailyInsight(userId, localDate)) ?? insight;
}
