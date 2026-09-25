-- One generated Today-tab insight per user per local calendar day (PRD user
-- stories 12–14). Stored so a reinstall, a cleared client cache, or a
-- second device doesn't trigger another model call for the same day —
-- the row is the rate limit.
--
-- local_date is the user's own calendar date as sent by the app, not the
-- server's UTC date, so "today's insight" rolls over at the user's midnight.
--
-- content holds only the generated card ({title, body, bullets, question}),
-- never the behavioral snapshot it was generated from.
CREATE TABLE daily_insights (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('insight', 'check_in')),
  content JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, local_date)
);
