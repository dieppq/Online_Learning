CREATE TABLE IF NOT EXISTS payments (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  course_id text NOT NULL,
  amount integer NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'VND',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  confirmed_at timestamptz
);
INSERT INTO payments(id,user_id,course_id,amount,currency,status) VALUES
  ('p-1001','u-1001','c-k8s-ckad',790000,'VND','pending')
ON CONFLICT DO NOTHING;
