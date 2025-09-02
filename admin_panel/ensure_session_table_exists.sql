-- ENSURE SESSION TABLE EXISTS WITH CORRECT STRUCTURE
-- Run this if you get table errors

-- 1. Check if table exists
SELECT 
  'TABLE CHECK' as step,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_name = 'class_attendance_sessions' 
        AND table_schema = 'public'
    ) THEN '✅ Table exists'
    ELSE '❌ Table missing'
  END as status;

-- 2. Create table if it doesn't exist (safe - won't overwrite)
CREATE TABLE IF NOT EXISTS public.class_attendance_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL,
  date date NOT NULL,
  subject_id uuid NULL,
  professor_id uuid NULL,
  attendance_data jsonb NOT NULL,
  total_students integer NOT NULL DEFAULT 0,
  present_count integer NOT NULL DEFAULT 0,
  absent_count integer NOT NULL DEFAULT 0,
  late_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT class_attendance_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT unique_class_date_subject UNIQUE (class_id, date, subject_id)
) TABLESPACE pg_default;

-- 3. Create indexes (safe - IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_date 
ON public.class_attendance_sessions USING btree (date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_class 
ON public.class_attendance_sessions USING btree (class_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_subject 
ON public.class_attendance_sessions USING btree (subject_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_professor 
ON public.class_attendance_sessions USING btree (professor_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_json 
ON public.class_attendance_sessions USING GIN (attendance_data) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_class_date 
ON public.class_attendance_sessions USING btree (class_id, date) TABLESPACE pg_default;

-- 4. Create trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_attendance_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger (safe - will replace if exists)
DROP TRIGGER IF EXISTS update_attendance_sessions_updated_at ON class_attendance_sessions;
CREATE TRIGGER update_attendance_sessions_updated_at 
  BEFORE UPDATE ON class_attendance_sessions 
  FOR EACH ROW EXECUTE FUNCTION update_attendance_sessions_updated_at();

-- 6. Verify table structure
SELECT 
  'VERIFICATION' as step,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'class_attendance_sessions' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 7. Test table access
SELECT 
  'ACCESS TEST' as step,
  COUNT(*) as existing_sessions,
  'Table is accessible' as status
FROM class_attendance_sessions;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Session table setup completed!';
  RAISE NOTICE '📊 Table: class_attendance_sessions';
  RAISE NOTICE '🔧 Indexes: All created';
  RAISE NOTICE '⚡ Trigger: Updated_at configured';
  RAISE NOTICE '🚀 Ready for optimized attendance saving!';
END $$;