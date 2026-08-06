CREATE TABLE IF NOT EXISTS users (
  id text PRIMARY KEY,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('student', 'instructor', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO users(id,name,email,role) VALUES
  ('u-1001','Nguyen An','an@example.com','student'),
  ('u-2001','Tran Linh','linh@example.com','instructor')
ON CONFLICT DO NOTHING;
