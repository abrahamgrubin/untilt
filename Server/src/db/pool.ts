import { Pool } from "pg";
import { env } from "../config/env.js";

export const pool = new Pool({
  connectionString: env.databaseUrl,
  // RDS requires TLS regardless of NODE_ENV (staging intentionally runs
  // with NODE_ENV=development for debug logging, but still talks to
  // real RDS) — set explicitly via DB_SSL, not inferred from NODE_ENV.
  ssl: env.DB_SSL ? { rejectUnauthorized: true } : undefined,
});
