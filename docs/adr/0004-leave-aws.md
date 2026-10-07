# ADR 0004 — Move off AWS to Supabase + Render (Supersedes ADR 0003 in part)

## Status
Accepted

## Context
ADR 0003 moved Compass and the system of record onto a custom backend, and
the architecture doc put it on AWS (`Infra/`). That backend decision still
holds. The AWS footprint does not: for an app with a handful of users it
cost roughly **$90–110/month** before any traffic, almost all of it fixed:

| Resource (Infra/) | Approx. monthly |
|---|---|
| NAT gateway (`vpc.tf`, needed so private Fargate tasks reach Anthropic) | ~$33 + data |
| Application Load Balancer (`alb.tf`) | ~$18 |
| Fargate API task, 0.5 vCPU / 1 GB, always on | ~$18 |
| Fargate worker task, 0.25 vCPU / 0.5 GB, always on | ~$9 |
| RDS `db.t4g.micro` + 20 GB storage | ~$14 |
| Public IPv4s, Secrets Manager, CloudWatch, ECR | ~$5–10 |

The stack was deleted to stop the spend, which left the app unable to sign
in or reach Compass.

Very little of the server was AWS-specific. Express, the Compass modes,
crisis detection and the Postgres schema are all portable. The coupling
was Cognito (token verification on the server, Hosted UI login in the
app), SQS (the worker queue), and the RDS CA certificate.

## Decision
- **Database + auth: Supabase** (free tier). It gives Postgres with
  pgvector, so the schema and `journal_entries.embedding` are unchanged,
  plus Auth with Apple, Google and email/password. Its user IDs are UUIDs,
  as Cognito's `sub` was, so `users.id` keeps its type.
  - The server verifies Supabase access tokens against the project's JWKS
    with `jose` (`Server/src/middleware/auth.ts`). Checks: issuer
    `<project>/auth/v1`, audience `authenticated`, ES256/RS256. HS256 is
    used only if `SUPABASE_JWT_SECRET` is set, for legacy projects.
  - The app talks to Supabase Auth's REST API directly
    (`Untilt/Services/AuthService.swift`), with no SDK dependency. Sign in
    with Apple uses the native sheet plus the `id_token` grant, which
    avoids Apple Services IDs and `.p8` keys entirely. Google uses hosted
    OAuth with PKCE.
  - The server reaches Postgres through Supabase's **session pooler**
    (port 5432). The direct connection is IPv6-only and Render can't
    reach it. TLS is verified against Supabase's root CA
    (`Server/certs/supabase-ca.crt`).
- **API hosting: Render**, Starter web service (~$7/month), defined in
  `render.yaml` and auto-deployed from `main`. The free plan sleeps after
  15 idle minutes, and a ~1 minute cold start during an urge-surfing
  session isn't acceptable. Free is fine for throwaway testing.
- **No queue service.** Session summarization runs in the API process,
  fire-and-forget (`Server/src/jobs/queue.ts`). The SQS worker is removed.
- **Data API locked down.** Supabase exposes `public` tables through a REST
  API reachable with the publishable key that ships in the app. Migration
  `0003_enable_rls.sql` enables RLS with no policies on every table, so
  only the server, as table owner, can read or write them. The Data API
  can also be switched off in project settings, which is extra protection.
- `Infra/` is kept for reference only and marked retired. CI no longer
  deploys anything; it only typechecks and tests.

## Consequences
- **Cost drops to ~$7/month** (Render Starter) plus usage-based Anthropic
  and Voyage. Supabase's free tier covers 500 MB of database and 50k
  monthly active users. Its Pro plan ($25/month) is the next step, for
  daily backups and no auto-pause.
- Supabase's free tier **pauses a project after 7 days without activity**.
  Fine for a demo; move to Pro before real users depend on it.
- **Summarization jobs aren't durable.** A job in flight during a deploy
  or crash is lost, so that one session's notes miss the memory profile.
  Nothing user-visible breaks. If this matters later, a Postgres-backed
  queue (pg-boss) adds durability without a new vendor.
- **Vendors now holding user data:** Supabase holds the database, which
  includes journal and conversation content, and identities. Render
  processes requests. Both need adding to the privacy policy and
  data-processing records in place of AWS. Supabase offers a BAA only on
  higher plans, which matters if the HIPAA-adjacent bar in PRD Section 9
  ever becomes a formal requirement.
- **Vendor lock-in is low.** The database is plain Postgres (`pg_dump`
  moves it anywhere). Auth is the stickier part: moving off Supabase Auth
  means re-verifying tokens and migrating identities, as Cognito did.
- No data migration. The RDS database was deleted with the stack, so
  everyone starts fresh, as with ADR 0003's clean break.
