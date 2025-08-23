-- STEP 3: CREATE OPTIMIZED HELPER FUNCTIONS
-- These functions provide fast access to attendance data

-- 3.1: Function to get student attendance (OPTIMIZED)
CREATE OR REPLACE FUNCTION get_student_attendance_optimized(student_roll VARCHAR)
RETURNS TABLE (
  session_id UUID,
  date DATE,
  status VARCHAR,
  subject_name VARCHAR,
  class_id UUID,
  professor_email VARCHAR,
  college_name VARCHAR,
  branch_name VARCHAR,
  semester_name VARCHAR,
  class_number INTEGER,
  marked_at TIMESTAMP,
  total_class_students INTEGER,
  present_in_class INTEGER,
  absent_in_class INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cas.id as session_id,
    cas.date,
    (student_data->>'status')::VARCHAR as status,
    s.name as subject_name,
    cas.class_id,
    p.email as professor_email,
    c.name as college_name,
    b.name as branch_name,
    sem.name as semester_name,
    1 as class_number, -- Default class number
    CASE 
      WHEN student_data->>'marked_at' IS NOT NULL 
      THEN (student_data->>'marked_at')::TIMESTAMP
      ELSE NULL 
    END as marked_at,
    cas.total_students as total_class_students,
    cas.present_count as present_in_class,
    cas.absent_count as absent_in_class
  FROM class_attendance_sessions cas
  JOIN subjects s ON s.id = cas.subject_id
  JOIN profiles p ON p.id = cas.professor_id
  LEFT JOIN semesters sem ON sem.id = s.semester_id
  LEFT JOIN branches b ON b.id = sem.branch_id
  LEFT JOIN colleges c ON c.id = b.college_id,
  jsonb_array_elements(cas.attendance_data->'students') as student_data
  WHERE student_data->>'roll_number' = student_roll
  ORDER BY cas.date DESC;
END;
$$ LANGUAGE plpgsql;

-- 3.2: Function to get student attendance statistics (SUPER FAST)
CREATE OR REPLACE FUNCTION get_student_attendance_stats_optimized(student_roll VARCHAR)
RETURNS TABLE (
  total_classes BIGINT,
  present_count BIGINT,
  absent_count BIGINT,
  late_count BIGINT,
  attendance_percentage NUMERIC,
  last_attendance_date DATE,
  subjects_count BIGINT,
  best_subject VARCHAR,
  worst_subject VARCHAR
) AS $$
BEGIN
  RETURN QUERY
  WITH student_stats AS (
    SELECT 
      COUNT(*) as total_classes,
      COUNT(CASE WHEN student_data->>'status' = 'present' THEN 1 END) as present_count,
      COUNT(CASE WHEN student_data->>'status' = 'absent' THEN 1 END) as absent_count,
      COUNT(CASE WHEN student_data->>'status' = 'late' THEN 1 END) as late_count,
      MAX(cas.date) as last_date,
      COUNT(DISTINCT cas.subject_id) as subjects_count
    FROM class_attendance_sessions cas,
    jsonb_array_elements(cas.attendance_data->'students') as student_data
    WHERE student_data->>'roll_number' = student_roll
  ),
  subject_performance AS (
    SELECT 
      s.name as subject_name,
      COUNT(CASE WHEN student_data->>'status' = 'present' THEN 1 END)::NUMERIC / 
      NULLIF(COUNT(*), 0) * 100 as subject_percentage
    FROM class_attendance_sessions cas
    JOIN subjects s ON s.id = cas.subject_id,
    jsonb_array_elements(cas.attendance_data->'students') as student_data
    WHERE student_data->>'roll_number' = student_roll
    GROUP BY s.name
    HAVING COUNT(*) > 0
  )
  SELECT 
    ss.total_classes,
    ss.present_count,
    ss.absent_count,
    ss.late_count,
    CASE 
      WHEN ss.total_classes > 0 THEN 
        ROUND((ss.present_count::NUMERIC / ss.total_classes * 100), 2)
      ELSE 0 
    END as attendance_percentage,
    ss.last_date as last_attendance_date,
    ss.subjects_count,
    (SELECT subject_name FROM subject_performance ORDER BY subject_percentage DESC LIMIT 1) as best_subject,
    (SELECT subject_name FROM subject_performance ORDER BY subject_percentage ASC LIMIT 1) as worst_subject
  FROM student_stats ss;
END;
$$ LANGUAGE plpgsql;

-- 3.3: Function to get class session summary (FOR ADMIN PANEL)
CREATE OR REPLACE FUNCTION get_class_session_summary(p_class_id UUID, p_date DATE)
RETURNS TABLE (
  session_id UUID,
  subject_name VARCHAR,
  professor_name VARCHAR,
  total_students INTEGER,
  present_count INTEGER,
  absent_count INTEGER,
  late_count INTEGER,
  attendance_percentage NUMERIC,
  session_created_at TIMESTAMP,
  students_data JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cas.id as session_id,
    s.name as subject_name,
    p.full_name as professor_name,
    cas.total_students,
    cas.present_count,
    cas.absent_count,
    cas.late_count,
    CASE 
      WHEN cas.total_students > 0 THEN 
        ROUND((cas.present_count::NUMERIC / cas.total_students * 100), 2)
      ELSE 0 
    END as attendance_percentage,
    cas.created_at as session_created_at,
    cas.attendance_data->'students' as students_data
  FROM class_attendance_sessions cas
  JOIN subjects s ON s.id = cas.subject_id
  JOIN profiles p ON p.id = cas.professor_id
  WHERE cas.class_id = p_class_id 
    AND cas.date = p_date;
END;
$$ LANGUAGE plpgsql;

-- 3.4: Function to migrate data from old table (SAFE MIGRATION)
CREATE OR REPLACE FUNCTION migrate_attendance_data_safe()
RETURNS TABLE (
  migration_status VARCHAR,
  sessions_created INTEGER,
  students_migrated INTEGER,
  errors_encountered INTEGER
) AS $$
DECLARE
  session_record RECORD;
  attendance_json JSONB;
  migrated_sessions INTEGER := 0;
  migrated_students INTEGER := 0;
  error_count INTEGER := 0;
  subject_id_val UUID;
  professor_id_val UUID;
BEGIN
  -- Loop through each unique session in old table
  FOR session_record IN
    SELECT 
      pa.date,
      pa.class_id,
      pa.subject_name,
      COUNT(*) as total_students,
      COUNT(CASE WHEN pa.status = 'present' THEN 1 END) as present_count,
      COUNT(CASE WHEN pa.status = 'absent' THEN 1 END) as absent_count,
      COUNT(CASE WHEN pa.status = 'late' THEN 1 END) as late_count
    FROM professor_attendance pa
    GROUP BY pa.date, pa.class_id, pa.subject_name
    ORDER BY pa.date, pa.class_id
  LOOP
    BEGIN
      -- Try to find subject_id
      SELECT id INTO subject_id_val 
      FROM subjects 
      WHERE name = session_record.subject_name 
      LIMIT 1;
      
      -- Try to find professor_id (get first professor as default)
      SELECT id INTO professor_id_val 
      FROM profiles 
      WHERE role = 'professor' 
      LIMIT 1;
      
      -- Build JSON array for this session
      SELECT jsonb_agg(
        jsonb_build_object(
          'roll_number', student_roll_number,
          'name', student_name,
          'status', status,
          'marked_at', CASE 
            WHEN status != 'absent' THEN date::timestamp 
            ELSE NULL 
          END
        )
      ) INTO attendance_json
      FROM professor_attendance
      WHERE date = session_record.date 
        AND class_id = session_record.class_id
        AND subject_name = session_record.subject_name;
      
      -- Insert into new table (use ON CONFLICT to handle duplicates)
      INSERT INTO class_attendance_sessions (
        class_id,
        date,
        subject_id,
        professor_id,
        attendance_data,
        total_students,
        present_count,
        absent_count,
        late_count
      ) VALUES (
        session_record.class_id,
        session_record.date,
        subject_id_val,
        professor_id_val,
        jsonb_build_object('students', attendance_json),
        session_record.total_students,
        session_record.present_count,
        session_record.absent_count,
        session_record.late_count
      )
      ON CONFLICT (class_id, date, subject_id) DO UPDATE SET
        attendance_data = EXCLUDED.attendance_data,
        total_students = EXCLUDED.total_students,
        present_count = EXCLUDED.present_count,
        absent_count = EXCLUDED.absent_count,
        late_count = EXCLUDED.late_count,
        updated_at = NOW();
      
      migrated_sessions := migrated_sessions + 1;
      migrated_students := migrated_students + session_record.total_students;
      
    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      RAISE NOTICE 'Error migrating session for date % class %: %', 
        session_record.date, session_record.class_id, SQLERRM;
    END;
  END LOOP;
  
  RETURN QUERY SELECT 
    'COMPLETED'::VARCHAR as migration_status,
    migrated_sessions as sessions_created,
    migrated_students as students_migrated,
    error_count as errors_encountered;
END;
$$ LANGUAGE plpgsql;

-- 3.5: Test the functions
SELECT 'FUNCTION TESTS' as step;

-- Test function creation
SELECT 
  'FUNCTIONS CREATED' as test_type,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%attendance%optimized%'
  OR routine_name LIKE '%migrate_attendance%'
  OR routine_name LIKE '%class_session%';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ STEP 3 COMPLETED SUCCESSFULLY!';
  RAISE NOTICE '🚀 Optimized functions created:';
  RAISE NOTICE '   - get_student_attendance_optimized()';
  RAISE NOTICE '   - get_student_attendance_stats_optimized()';
  RAISE NOTICE '   - get_class_session_summary()';
  RAISE NOTICE '   - migrate_attendance_data_safe()';
  RAISE NOTICE '🎯 Ready for Step 4: Test migration';
END $$;