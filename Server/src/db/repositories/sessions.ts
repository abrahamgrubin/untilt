import { pool } from "../pool.js";
import type { CompassMode } from "../../ai/prompts.js";
import type { ChatMessage } from "../../ai/claude.js";
import type { CompassSession } from "../../session/types.js";

// Postgres-backed replacement for the step-2 in-memory sessionStore.ts —
// same shape/responsibilities, now durable and shared across backend
// instances. history is loaded from the messages table on read rather
// than kept in the session row itself.

export async function createSession(userId: string, mode: CompassMode): Promise<CompassSession> {
  const { rows } = await pool.query<{ id: string; started_at: Date }>(
    `INSERT INTO sessions (user_id, mode) VALUES ($1, $2) RETURNING id, started_at`,
    [userId, mode]
  );
  return {
    id: rows[0].id,
    userId,
    mode,
    history: [],
    turnCount: 0,
    createdAt: rows[0].started_at.getTime(),
  };
}

export async function getSession(id: string, userId: string): Promise<CompassSession | undefined> {
  const { rows } = await pool.query<{
    id: string;
    user_id: string;
    mode: CompassMode;
    turn_count: number;
    started_at: Date;
  }>(
    `SELECT id, user_id, mode, turn_count, started_at FROM sessions
     WHERE id = $1 AND user_id = $2`,
    [id, userId]
  );
  if (rows.length === 0) return undefined;
  const row = rows[0];

  const { rows: messageRows } = await pool.query<{ role: "user" | "assistant"; content: string }>(
    `SELECT role, content FROM messages WHERE session_id = $1 ORDER BY created_at ASC`,
    [id]
  );

  return {
    id: row.id,
    userId: row.user_id,
    mode: row.mode,
    turnCount: row.turn_count,
    createdAt: row.started_at.getTime(),
    history: messageRows as ChatMessage[],
  };
}

export async function appendTurn(
  session: CompassSession,
  userMessage: string,
  assistantMessage: string
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO messages (session_id, role, content) VALUES ($1, 'user', $2), ($1, 'assistant', $3)`,
      [session.id, userMessage, assistantMessage]
    );
    await client.query(`UPDATE sessions SET turn_count = turn_count + 1 WHERE id = $1`, [session.id]);
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
  session.turnCount += 1;
  session.history.push({ role: "user", content: userMessage }, { role: "assistant", content: assistantMessage });
}

// Marks a session ended and returns it — used to trigger the memory-profile
// summarization job (jobs/summarizeSession.ts).
export async function endSession(id: string, userId: string): Promise<CompassSession | undefined> {
  const session = await getSession(id, userId);
  if (!session) return undefined;
  await pool.query(`UPDATE sessions SET ended_at = now() WHERE id = $1`, [id]);
  return session;
}
