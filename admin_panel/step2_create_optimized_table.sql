-- STEP 2: CREATE NEW OPTIMIZED ATTENDANCE TABLE
-- This creates the session-based table alongside your existing one

-- 2.1: Create the new optimized table structure
CREATE TABLE IF NOT EXISTS class_attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL,
  date DATE NOT NULL,
  subject_id UUID REFERENCES subjects(id),
  professor_id UUID REFERENCES profiles(id),
  attendance_data JSONB NOT NULL,
  total_students INTEGER NOT NULL DEFAULT 0,
  present_count INTEGER NOT NULL DEFAULT 0,
  absent_count INTEGER NOT NULL DEFAULT 0,
  late_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT class_attendance_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT unique_class_date_subject UNIQUE (class_id, date, subject_id),
  CONSTRAINT valid_counts CHECK (
    total_students = present_count + absent_count + late_count
  ),
  CONSTRAINT valid_attendance_data CHECK (
    attendance_data ? 'students' AND 
    jsonb_typeof(attendance_data->'students') = 'array'
  )
) TABLESPACE pg_default;

-- 2.2: Create optimized indexes
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_date 
ON class_attendance_sessions USING btree (date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_class 
ON class_attendance_sessions USING btree (class_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_subject 
ON class_attendance_sessions USING btree (subject_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_professor 
ON class_attendance_sessions USING btree (professor_id) TABLESPACE pg_default;

-- JSONB GIN index for fast student lookups
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_json 
ON class_attendance_sessions USING GIN (attendance_data) TABLESPACE pg_default;

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_class_date 
ON class_attendance_sessions USING btree (class_id, date) TABLESPACE pg_default;

-- 2.3: Create updated_at trigger
CREATE OR REPLACE FUNCTION update_attendance_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_attendance_sessions_updated_at 
  BEFORE UPDATE ON class_attendance_sessions 
  FOR EACH ROW EXECUTE FUNCTION update_attendance_sessions_updated_at();

-- 2.4: Enable Row Level Security (optional, for security)
ALTER TABLE class_attendance_sessions ENABLE ROW LEVEL SECURITY;

-- 2.5: Create RLS policies
CREATE POLICY "Enable professors to manage their class attendance sessions" 
ON class_attendance_sessions
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM professor_classes 
    WHERE professor_classes.id = class_attendance_sessions.class_id 
    AND professor_classes.user_id = auth.uid()
  )
);

-- Allow students to view sessions where they are included
CREATE POLICY "Enable students to view their attendance sessions" 
ON class_attendance_sessions
FOR SELECT USING (
  attendance_data->'students' @> jsonb_build_array(
    jsonb_build_object(
      'roll_number', 
      (SELECT roll_number FROM student_profiles WHERE user_id = auth.uid())
    )
  )
);

-- 2.6: Verify new table was created successfully
SELECT 
  'NEW TABLE VERIFICATION' as step,
  table_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_name = 'class_attendance_sessions' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2.7: Check new indexes
SELECT 
  'NEW INDEXES VERIFICATION' as step,
  indexname,
  indexdef
FROM pg_indexes 
WHERE tablename = 'class_attendance_sessions' 
  AND schemaname = 'public';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ STEP 2 COMPLETED SUCCESSFULLY!';
  RAISE NOTICE '🚀 New optimized table: class_attendance_sessions';
  RAISE NOTICE '📊 Indexes created for maximum performance';
  RAISE NOTICE '🔐 Row Level Security enabled';
  RAISE NOTICE '🎯 Ready for Step 3: Create helper functions';
END $$;