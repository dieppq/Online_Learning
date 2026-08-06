ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content_object_key text;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content_type text;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content_size bigint CHECK (content_size >= 0);
