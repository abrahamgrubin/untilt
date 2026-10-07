import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),

  // Supabase Auth issues the access tokens the app sends (see
  // middleware/auth.ts and docs/adr/0004-leave-aws.md). The project URL is
  // all that's needed to verify them — public keys come from its JWKS.
  SUPABASE_URL: z.string().url("SUPABASE_URL must be the project URL, e.g. https://abcd.supabase.co"),
  // Only for projects still on the legacy shared-secret (HS256) signing.
  // Leave unset on projects using asymmetric signing keys (the default).
  SUPABASE_JWT_SECRET: z.string().optional(),
  // Secret key (`sb_secret_…`, or legacy service_role) for the Auth admin
  // API. Server-only; never ship it in the app. Used solely to delete a
  // user's login when they delete their account (routes/account.ts), which
  // returns 503 if this is unset.
  SUPABASE_SECRET_KEY: z.string().optional(),

  ANTHROPIC_API_KEY: z.string().min(1, "ANTHROPIC_API_KEY is required"),
  VOYAGE_API_KEY: z.string().min(1, "VOYAGE_API_KEY is required"),

  // Local dev: any Postgres 15+ with pgvector. Hosted: Supabase's session
  // pooler string (port 5432) — the direct connection is IPv6-only, which
  // Render can't reach.
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),

  // Decoupled from NODE_ENV on purpose: you may want debug logging while
  // pointed at the hosted database, which requires TLS.
  DB_SSL: z
    .string()
    .optional()
    .default("false")
    .transform((v) => v === "true"),
  // CA used to verify the database's certificate when DB_SSL=true. Supabase
  // signs with its own root CA (downloadable from Database settings), so the
  // system trust store isn't enough. Relative to Server/.
  DB_SSL_CA_FILE: z.string().default("certs/supabase-ca.crt"),
});

export type Env = z.infer<typeof envSchema>;

function loadEnv(): Env {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error("Invalid environment configuration:");
    console.error(parsed.error.flatten().fieldErrors);
    process.exit(1);
  }
  return parsed.data;
}

export const env = loadEnv();
