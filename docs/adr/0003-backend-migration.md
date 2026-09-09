# ADR 0003 — Backend Migration (Supersedes ADR 0001 in part)

## Status
Accepted

## Context
ADR 0001 chose SwiftData + CloudKit specifically to avoid building a custom
backend, accepting "no Google Sign-In" as a tradeoff. ADR 0002 has Compass
calling the Claude API directly from the client, with the API key bundled
in the app — flagged at the time as acceptable for beta only.

Two things changed:
1. Google Sign-In and local email/password accounts are now required.
   CloudKit sync is tied to iCloud/Apple ID, so there's no clean way to
   add non-Apple identity on top of a CloudKit-as-source-of-truth model.
2. The bundled API key was always meant to move server-side before public
   launch — it's a real exposure risk as-is (any user can extract it from
   the app binary).

The fuller Compass design (urge surfing / journaling / listening as
distinct modes, deterministic + LLM crisis detection, a cross-session
memory profile) also can't live entirely on-device — see the project
architecture doc for the full reasoning.

## Decision
Supersede the auth and data-ownership portions of ADR 0001:

- **Auth**: AWS Cognito, supporting Sign in with Apple (existing), Google
  Sign-In (new), and local email/password accounts. Cognito issues a
  uniform token regardless of provider, verified by the backend.
- **System of record**: PostgreSQL on RDS becomes the source of truth for
  users, sessions, journal entries, and the memory profile. SwiftData
  remains on-device as a local cache/offline layer, not the source of
  truth.
- **Compass**: moves from direct client-to-Anthropic calls to a backend
  service that owns the Anthropic API key, orchestrates the three modes,
  and runs crisis detection independently of the main conversation.
- **Migration**: clean break — no migration path for existing CloudKit
  beta data. Given the small beta population, this was judged simpler and
  lower-risk than building a one-time CloudKit → Postgres import.

ADR 0001's choice of SwiftData for on-device persistence stands; only the
"no backend, CloudKit as source of truth" portion is superseded.

## Consequences
- Existing beta users lose their local history on the update that ships
  this change (accepted tradeoff, see above).
- API key exposure is fixed — it now lives only in the backend's secret
  store, never in the client binary.
- Real backend infrastructure now exists to build and operate (see the
  project architecture doc for the AWS design: Fargate/ECS, RDS+pgvector,
  SQS, CloudWatch, GitHub Actions).
- Google Sign-In and local accounts become possible.
- Compass can now implement the fuller mode/crisis-detection design from
  the PRD, which wasn't practically buildable as a single client-side
  prompt.
