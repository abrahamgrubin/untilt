-- Hosting moved to Supabase (docs/adr/0004-leave-aws.md). Supabase exposes
-- every table in the public schema through its auto-generated Data API,
-- reachable with the project's public anon/publishable key, which ships in
-- the iOS app. Row-level security with no policies denies all access
-- through that API, so these tables are only reachable via this server.
--
-- The server connects as the table owner, and owners bypass RLS (we
-- deliberately don't FORCE it), so no server queries change.
--
-- users.id now holds the Supabase Auth user id (a UUID, like the Cognito
-- `sub` it replaced). There was no data migration: the RDS database was
-- deleted along with the rest of the AWS stack.

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE crisis_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE schema_migrations ENABLE ROW LEVEL SECURITY;
