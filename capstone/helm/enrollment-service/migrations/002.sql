CREATE TABLE IF NOT EXISTS enrollments (
  id text PRIMARY KEY,
  user_id text NOT NULL,
  course_id text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  source_event_id text UNIQUE,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, course_id)
);
CREATE TABLE IF NOT EXISTS progress (
  user_id text NOT NULL,
  course_id text NOT NULL,
  completed_lessons integer NOT NULL DEFAULT 0,
  total_lessons integer NOT NULL DEFAULT 18,
  progress_percentage integer NOT NULL DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
  last_lesson_id text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, course_id)
);
INSERT INTO enrollments(id,user_id,course_id,status) VALUES
  ('e-1001','u-1001','c-k8s-ckad','active')
ON CONFLICT DO NOTHING;
INSERT INTO progress(user_id,course_id,completed_lessons,total_lessons,progress_percentage,last_lesson_id) VALUES
  ('u-1001','c-k8s-ckad',7,18,39,'l-03')
ON CONFLICT DO NOTHING;
