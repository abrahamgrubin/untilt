-- Tombstones for deleted accounts (routes/account.ts). An access token stays
-- valid until it expires (an hour by default) even after the Supabase login
-- is deleted, and every route lazily recreates the users row (ensureUser).
-- Without this, a late request from a deleted account's token would quietly
-- re-create the account and start storing data the person can no longer
-- delete. Rows hold only the id and are purged after a day (see
-- repositories/users.ts) — keep the project's JWT expiry well under that.

CREATE TABLE deleted_users (
  id UUID PRIMARY KEY,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Same Data API lockdown as 0003.
ALTER TABLE deleted_users ENABLE ROW LEVEL SECURITY;
