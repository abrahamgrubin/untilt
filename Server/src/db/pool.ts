import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Pool } from "pg";
import { env } from "../config/env.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// TLS is set explicitly via DB_SSL, not inferred from NODE_ENV. We verify
// against the database provider's CA (DB_SSL_CA_FILE, e.g. Supabase's root
// cert committed under certs/) rather than disabling certificate checks.
function sslConfig() {
  if (!env.DB_SSL) return undefined;
  const caPath = path.resolve(__dirname, "../..", env.DB_SSL_CA_FILE);
  return { ca: readFileSync(caPath, "utf-8"), rejectUnauthorized: true };
}

export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  ssl: sslConfig(),
});
