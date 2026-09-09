import { Pool } from "pg";
import { env } from "../config/env.js";

export const pool = new Pool({
  connectionString: env.databaseUrl,
  // RDS in production requires TLS; local/dev Postgres typically doesn't
  // present a cert, so we only enforce this outside development.
  ssl: env.NODE_ENV === "production" ? { rejectUnauthorized: true } : undefined,
});
