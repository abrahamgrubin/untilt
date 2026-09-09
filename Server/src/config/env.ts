import "dotenv/config";
import { z } from "zod";

const envSchema = z
  .object({
    PORT: z.coerce.number().default(8080),
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),

    COGNITO_USER_POOL_ID: z.string().min(1, "COGNITO_USER_POOL_ID is required"),
    COGNITO_CLIENT_ID: z.string().min(1, "COGNITO_CLIENT_ID is required"),
    COGNITO_REGION: z.string().default("us-east-1"),

    ANTHROPIC_API_KEY: z.string().min(1, "ANTHROPIC_API_KEY is required"),
    VOYAGE_API_KEY: z.string().min(1, "VOYAGE_API_KEY is required"),

    // Local dev: set DATABASE_URL directly (see .env.example).
    // Production (Infra/ecs.tf): RDS's managed-master-password secret only
    // exposes username/password as a JSON secret, not a full connection
    // string, so the ECS task definition instead injects the parts
    // separately (DB_HOST/DB_PORT/DB_NAME as plain env vars, DB_USER/
    // DB_PASSWORD from the secret's JSON keys) and this file assembles the
    // connection string from them at boot.
    DATABASE_URL: z.string().optional(),
    DB_HOST: z.string().optional(),
    DB_PORT: z.coerce.number().default(5432),
    DB_NAME: z.string().optional(),
    DB_USER: z.string().optional(),
    DB_PASSWORD: z.string().optional(),

    // Decoupled from NODE_ENV on purpose: staging runs against real RDS
    // (which requires TLS) but wants NODE_ENV=development for debug
    // logging, so SSL enforcement needs its own explicit flag.
    DB_SSL: z
      .string()
      .optional()
      .default("false")
      .transform((v) => v === "true"),

    SQS_QUEUE_URL: z.string().optional(),
  })
  .refine((env) => env.DATABASE_URL || (env.DB_HOST && env.DB_NAME && env.DB_USER && env.DB_PASSWORD), {
    message: "Either DATABASE_URL, or all of DB_HOST/DB_NAME/DB_USER/DB_PASSWORD, must be set",
  });

export type Env = z.infer<typeof envSchema> & { databaseUrl: string };

function loadEnv(): Env {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error("Invalid environment configuration:");
    console.error(parsed.error.flatten().fieldErrors);
    process.exit(1);
  }
  const env = parsed.data;
  const databaseUrl =
    env.DATABASE_URL ??
    `postgres://${encodeURIComponent(env.DB_USER!)}:${encodeURIComponent(env.DB_PASSWORD!)}@${env.DB_HOST}:${env.DB_PORT}/${env.DB_NAME}`;

  return { ...env, databaseUrl };
}

export const env = loadEnv();
