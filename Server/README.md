# Untilt Server

Backend API for the Compass agent (urge surfing, journaling, non-judgmental
listening, crisis detection) and the Today-tab insight in the Untilt iOS
app. Runs on **Render**, with **Supabase** for Postgres (pgvector) and
Auth. See `docs/adr/0003-backend-migration.md` for why there's a backend,
and `docs/adr/0004-leave-aws.md` for why it's no longer on AWS.

## Routes

- `GET /health` — unauthenticated liveness check (Render health check).
- `POST /session`, `POST /session/:id/message` (SSE), `POST /session/:id/end`
- `POST /journal`
- `POST /insight`

Everything except `/health` requires a Supabase access token
(`Authorization: Bearer …`), verified against the project's JWKS in
`src/middleware/auth.ts`.

## First-time hosted setup (~30 min)

### 1. Supabase (free)
1. Create a project at [supabase.com](https://supabase.com) and save the
   database password.
2. **Connect** (top bar) → **Session pooler** → copy the URI. This is
   `DATABASE_URL`. Use the pooler, not the direct connection: the direct
   connection is IPv6-only and Render can't reach it.
3. **Database settings → SSL** → download the CA certificate and save it as
   `Server/certs/supabase-ca.crt`. It's public, so commit it.
4. **Authentication → Sign In / Providers**:
   - **Email**: enabled. For a quick demo account, turn off "Confirm email",
     or leave it on and click the link Supabase sends.
   - **Apple** (optional): enable it and add the app's bundle ID under
     *Client IDs*. The app uses the native sheet, so no Services ID, key
     or secret is needed.
   - **Google** (optional): enable it with a Google Cloud OAuth client ID
     and secret.
5. **Authentication → URL Configuration → Redirect URLs**: add
   `untilt://auth-callback` (used by Google sign-in).
6. **Project Settings → API**: copy the Project URL (`SUPABASE_URL`) and the
   **publishable** key. Both go into `Untilt/Services/AppConfig.swift`.
   Never put the secret/service-role key in the app.
7. Optional extra protection: **Project Settings → Data API** → turn off the
   Data API. Nothing uses it, and migration `0003_enable_rls.sql` already
   denies all access through it.

### 2. Render (~$7/mo Starter)
1. Render → **New → Blueprint** → connect this GitHub repo. It reads
   `render.yaml` at the repo root.
2. Fill in the secret env vars it asks for: `SUPABASE_URL`, `DATABASE_URL`,
   `ANTHROPIC_API_KEY`, `VOYAGE_API_KEY`.
3. Deploy. Migrations run on boot. Check
   `https://<service>.onrender.com/health` returns `{"status":"ok"}`.
4. Put that URL in `AppConfig.backendURL` in the iOS app.

Pushes to `main` redeploy automatically. GitHub Actions
(`backend-ci.yml`) only typechecks and runs the tests.

## Local development

Needs Postgres 15+ with pgvector, e.g. `brew install postgresql@16 pgvector`,
then `createdb untilt`. Or point `DATABASE_URL` at the Supabase pooler with
`DB_SSL=true`.

```bash
npm install
cp .env.example .env   # fill in values
npm run db:migrate
npm run dev
```

The iOS simulator can use a local server by setting
`AppConfig.backendURL` to `http://localhost:8080`. App Transport Security
blocks plain HTTP, so you'll need a temporary ATS exception (local
networking) for that.

## Tests

```bash
npm run typecheck
npm test
```
