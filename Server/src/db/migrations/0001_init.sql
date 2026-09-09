-- Initial schema. Postgres becomes the system of record for users, sessions,
-- journal entries, and the memory profile (ADR 0003; supersedes CloudKit as
-- source of truth from ADR 0001).

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- gen_random_uuid()

-- id matches the Cognito `sub` claim — the same stable identifier across
-- Apple SSO, Google SSO, and local email/password (see auth middleware).
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('urge_surfing', 'journaling', 'listening')),
  turn_count INTEGER NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ
);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_session_id ON messages(session_id);

-- Embedding dimension (1024) matches Voyage AI's voyage-3-lite model.
-- If the embedding model changes, this column (and the index) need a
-- migration — dimension is not something we can change in place.
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  embedding VECTOR(1024),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_journal_entries_user_id ON journal_entries(user_id);
-- HNSW index for approximate nearest-neighbor retrieval (PRD 13.3: past
-- entries retrieved selectively by relevance, not replayed wholesale).
CREATE INDEX idx_journal_entries_embedding ON journal_entries
  USING hnsw (embedding vector_cosine_ops);

-- One row per user: the compact cross-session memory profile (PRD 13.3).
CREATE TABLE memory_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  profile JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit trail for crisis detections (PRD Section 8 auditability + Section 10
-- "crisis-resource surfacing rate" metric). Deliberately stores no message
-- content — source and timing only, consistent with treating conversation
-- content as health data (PRD Section 9).
CREATE TABLE crisis_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  source TEXT NOT NULL CHECK (source IN ('keyword', 'llm')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_crisis_events_user_id ON crisis_events(user_id);
