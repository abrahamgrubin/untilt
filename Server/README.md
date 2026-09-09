# Untilt Server

Backend API for the Compass agent (urge surfing, journaling, non-judgmental
listening, crisis detection) inside the Untilt iOS app. See
`docs/architecture-design-doc.md` (project-level) and
`docs/adr/0003-backend-migration.md` for the decisions behind this.

## Status: skeleton (step 1 of 4)

This is the **backend service skeleton + auth** step only:

- Express app with structured logging (pino), security headers (helmet).
- `GET /health` — unauthenticated liveness check.
- `GET /session/me` — authenticated example route; verifies a Cognito
  access token (Apple SSO, Google SSO, and local email/password all issue
  the same Cognito token shape, so this one middleware covers all three).
- No database yet, no Claude calls yet, no crisis detection yet.

**Not done yet** (later steps, one at a time per plan):
1. ~~Backend service skeleton + auth~~ ← you are here
2. AI/model orchestration — mode-specific Claude calls (Sonnet for urge
   surfing/journaling, Haiku for listening), the two-layer crisis-detection
   pass, prompt caching.
3. Data layer — Postgres schema/migrations, pgvector journal retrieval,
   the memory-profile async job.
4. Infrastructure — Terraform/CDK for ECS/Fargate, RDS, SQS, Cognito user
   pool provisioning, CI/CD via GitHub Actions.

## Setup

```bash
npm install
cp .env.example .env   # fill in Cognito + Anthropic values
npm run dev
```

## Cognito prerequisites (not yet provisioned)

This skeleton expects a Cognito User Pool with:
- Sign in with Apple configured as a federated identity provider.
- Google configured as a federated identity provider.
- Native (local) sign-up/sign-in enabled for email/password accounts.

Provisioning that pool is part of step 4 (Infrastructure). Until then, set
`COGNITO_USER_POOL_ID` / `COGNITO_CLIENT_ID` to a manually created pool in
the AWS console if you want to test auth locally before the IaC exists.
