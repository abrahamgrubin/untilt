import type { NextFunction, Request, Response } from "express";
import { CognitoJwtVerifier } from "aws-jwt-verify";
import { env } from "../config/env.js";

// Verifies Cognito-issued access tokens. Covers all three sign-in paths
// (Apple SSO, Google SSO, local email/password) uniformly, since Cognito
// issues the same token shape regardless of which identity provider was used.
const verifier = CognitoJwtVerifier.create({
  userPoolId: env.COGNITO_USER_POOL_ID,
  tokenUse: "access",
  clientId: env.COGNITO_CLIENT_ID,
});

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
    const payload = await verifier.verify(token);
    req.userId = payload.sub;
    next();
  } catch (err) {
    req.log?.warn({ err }, "token verification failed");
    res.status(401).json({ error: "invalid_token" });
  }
}
