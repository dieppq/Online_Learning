CREATE TABLE IF NOT EXISTS notifications (
  id text PRIMARY KEY,
  event_id text UNIQUE,
  type text NOT NULL,
  recipient text NOT NULL,
  user_id text,
  course_id text,
  status text NOT NULL DEFAULT 'queued',
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO notifications(id,type,recipient,user_id,course_id,status) VALUES
  ('n-1001','welcome','an@example.com','u-1001',NULL,'sent')
ON CONFLICT DO NOTHING;
