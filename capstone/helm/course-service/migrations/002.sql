CREATE TABLE IF NOT EXISTS courses (
  id text PRIMARY KEY,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  price integer NOT NULL CHECK (price >= 0),
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS lessons (
  id text PRIMARY KEY,
  course_id text NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title text NOT NULL,
  duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
  position integer NOT NULL,
  UNIQUE(course_id, position)
);
INSERT INTO courses(id,title,description,price,status) VALUES
  ('c-go-101','Go for backend services','Build practical Go HTTP services.',490000,'published'),
  ('c-k8s-ckad','Kubernetes CKAD hands-on','Deploy and debug LearnHub on Kubernetes.',790000,'published'),
  ('c-sql-basic','PostgreSQL for web applications','Relational data fundamentals.',390000,'published')
ON CONFLICT DO NOTHING;
INSERT INTO lessons(id,course_id,title,duration_minutes,position) VALUES
  ('l-01','c-k8s-ckad','Pod and namespace',18,1),
  ('l-02','c-k8s-ckad','Deployment and rollout',24,2),
  ('l-03','c-k8s-ckad','Service and internal DNS',21,3)
ON CONFLICT DO NOTHING;
