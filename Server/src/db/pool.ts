import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Pool } from "pg";
import { env } from "../config/env.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// RDS requires TLS regardless of NODE_ENV (staging intentionally runs
// with NODE_ENV=development for debug logging, but still talks to real
// RDS) — set explicitly via DB_SSL, not inferred from NODE_ENV. We
// validate against Amazon's actual RDS CA bundle (committed at
// certs/rds-global-bundle.pem, copied into the image by the Dockerfile)
// rather than disabling certificate verification.
function sslConfig() {
  if (!env.DB_SSL) return undefined;
  const caPath = path.join(__dirname, "../../certs/rds-global-bundle.pem");
  return { ca: readFileSync(caPath, "utf-8"), rejectUnauthorized: true };
}

export const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: sslConfig(),
});
