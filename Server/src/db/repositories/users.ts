import { pool } from "../pool.js";

// Upserted lazily on first authenticated request (see routes/session.ts) —
// Supabase Auth is the identity source of truth, this just ensures a matching
// row exists locally for foreign-key references.
//
// Returns false for a recently deleted account (see 0004_deleted_users.sql);
// callers must reject the request rather than recreate the user.
export async function ensureUser(userId: string, email?: string): Promise<boolean> {
  const { rows } = await pool.query<{ exists: boolean }>(
    `WITH inserted AS (
       INSERT INTO users (id, email)
       SELECT $1, $2
       WHERE NOT EXISTS (SELECT 1 FROM deleted_users WHERE id = $1)
       ON CONFLICT (id) DO NOTHING
       RETURNING id
     )
     SELECT EXISTS (SELECT 1 FROM inserted) OR EXISTS (SELECT 1 FROM users WHERE id = $1) AS exists`,
    [userId, email ?? null]
  );
  return rows[0]?.exists ?? false;
}

// Every other table references users(id) with ON DELETE CASCADE (see the
// migrations), so deleting the row removes all of a user's sessions,
// messages, journal entries, memory profile, insights and crisis events.
// The tombstone stops a still-valid token from recreating the account.
export async function deleteUser(userId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO deleted_users (id) VALUES ($1) ON CONFLICT (id) DO UPDATE SET deleted_at = now()`,
      [userId]
    );
    await client.query(`DELETE FROM users WHERE id = $1`, [userId]);
    await client.query(`DELETE FROM deleted_users WHERE deleted_at < now() - interval '1 day'`);
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// Withdrawing Compass consent with "delete history": everything Compass
// produced or remembers. Messages cascade from sessions. crisis_events are
// kept: they hold no content, and they're what keeps the post-crisis
// check-in card (with helplines) showing for 72 hours.
export async function deleteCompassData(userId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(`DELETE FROM sessions WHERE user_id = $1`, [userId]);
    await client.query(`DELETE FROM memory_profiles WHERE user_id = $1`, [userId]);
    await client.query(`DELETE FROM daily_insights WHERE user_id = $1`, [userId]);
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
