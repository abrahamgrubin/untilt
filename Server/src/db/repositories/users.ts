import { pool } from "../pool.js";

// Upserted lazily on first authenticated request (see routes/session.ts) —
// Cognito is the identity source of truth, this just ensures a matching
// row exists locally for foreign-key references.
export async function ensureUser(userId: string, email?: string): Promise<void> {
  await pool.query(
    `INSERT INTO users (id, email) VALUES ($1, $2)
     ON CONFLICT (id) DO NOTHING`,
    [userId, email ?? null]
  );
}
