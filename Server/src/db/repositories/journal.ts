import { pool } from "../pool.js";
import { embed } from "../../ai/embeddings.js";

export interface JournalEntry {
  id: string;
  content: string;
  createdAt: string;
}

export async function createJournalEntry(
  userId: string,
  content: string,
  sessionId?: string
): Promise<JournalEntry> {
  const embedding = await embed(content);
  const { rows } = await pool.query<{ id: string; content: string; created_at: Date }>(
    `INSERT INTO journal_entries (user_id, session_id, content, embedding)
     VALUES ($1, $2, $3, $4)
     RETURNING id, content, created_at`,
    [userId, sessionId ?? null, content, `[${embedding.join(",")}]`]
  );
  const row = rows[0];
  return { id: row.id, content: row.content, createdAt: row.created_at.toISOString() };
}

export async function listJournalEntries(userId: string, limit = 50): Promise<JournalEntry[]> {
  const { rows } = await pool.query<{ id: string; content: string; created_at: Date }>(
    `SELECT id, content, created_at FROM journal_entries
     WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
    [userId, limit]
  );
  return rows.map((r) => ({ id: r.id, content: r.content, createdAt: r.created_at.toISOString() }));
}

// Semantic retrieval (PRD 13.3) — used when starting a new session to pull
// in a handful of thematically relevant past entries, instead of replaying
// full journal history into context.
export async function retrieveRelevantEntries(
  userId: string,
  queryText: string,
  limit = 3
): Promise<JournalEntry[]> {
  const queryEmbedding = await embed(queryText);
  const { rows } = await pool.query<{ id: string; content: string; created_at: Date }>(
    `SELECT id, content, created_at FROM journal_entries
     WHERE user_id = $1
     ORDER BY embedding <=> $2
     LIMIT $3`,
    [userId, `[${queryEmbedding.join(",")}]`, limit]
  );
  return rows.map((r) => ({ id: r.id, content: r.content, createdAt: r.created_at.toISOString() }));
}

// Permanent delete, required for MVP (PRD 7.2/9) — a hard DELETE, not a
// soft-delete flag, given the sensitivity of this content.
export async function deleteJournalEntry(userId: string, entryId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM journal_entries WHERE id = $1 AND user_id = $2`, [
    entryId,
    userId,
  ]);
  return (result.rowCount ?? 0) > 0;
}

export async function deleteAllJournalEntries(userId: string): Promise<void> {
  await pool.query(`DELETE FROM journal_entries WHERE user_id = $1`, [userId]);
}
