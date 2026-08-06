CREATE TABLE IF NOT EXISTS outbox_events (
  id text PRIMARY KEY,
  subject text NOT NULL,
  payload jsonb NOT NULL,
  published_at timestamptz,
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS outbox_events_pending_idx
  ON outbox_events(created_at)
  WHERE published_at IS NULL;
