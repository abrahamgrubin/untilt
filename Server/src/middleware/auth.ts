import type { NextFunction, Request, Response } from "express";
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "jose";
import { env } from "../config/env.js";

// Verifies Supabase Auth access tokens. Covers every sign-in path (Apple,
// Google, email/password) uniformly, since Supabase issues the same token
// shape regardless of provider. `sub` is the Supabase user's UUID, which is
// what users.id holds.
const issuer = `${env.SUPABASE_URL.replace(/\/$/, "")}/auth/v1`;
const jwks = createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`));
const legacySecret = env.SUPABASE_JWT_SECRET ? new TextEncoder().encode(env.SUPABASE_JWT_SECRET) : null;

async function verify(token: string): Promise<JWTPayload> {
  const options = { issuer, audience: "authenticated" };
  if (legacySecret) {
    const { payload } = await jwtVerify(token, legacySecret, { ...options, algorithms: ["HS256"] });
    return payload;
  }
  const { payload } = await jwtVerify(token, jwks, { ...options, algorithms: ["ES256", "RS256"] });
  return payload;
}

export interface AuthedRequest extends Request {
  userId?: string;
}

export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "missing_bearer_token" });
    return;
  }

  const token = header.slice("Bearer ".length);

  try {
    const payload = await verify(token);
    if (!payload.sub) throw new Error("token has no sub claim");
    req.userId = payload.sub;
    next();
  } catch (err) {
    req.log?.warn({ err }, "token verification failed");
    res.status(401).json({ error: "invalid_token" });
  }
}
