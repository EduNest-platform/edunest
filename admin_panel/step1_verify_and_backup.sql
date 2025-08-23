-- STEP 1: VERIFY CURRENT SYSTEM & CREATE SAFETY BACKUP
-- Run this first to ensure we understand what we're working with

-- 1.1: Check current table structure
SELECT 
  'CURRENT SCHEMA CHECK' as step,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'professor_attendance' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 1.2: Check current data volume
SELECT 
  'DATA VOLUME CHECK' as step,
  COUNT(*) as total_records,
  COUNT(DISTINCT student_roll_number) as unique_students,
  COUNT(DISTINCT date) as unique_dates,
  COUNT(DISTINCT subject_name) as unique_subjects,
  COUNT(DISTINCT class_id) as unique_classes,
  MIN(date) as earliest_date,
  MAX(date) as latest_date
FROM professor_attendance;

-- 1.3: Check current constraints and indexes
SELECT 
  'CONSTRAINTS CHECK' as step,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'professor_attendance' 
  AND table_schema = 'public';

SELECT 
  'INDEXES CHECK' as step,
  indexname,
  indexdef
FROM pg_indexes 
WHERE tablename = 'professor_attendance' 
  AND schemaname = 'public';

-- 1.4: Sample current data structure
SELECT 
  'SAMPLE DATA' as step,
  id,
  class_id,
  student_roll_number,
  student_name,
  date,
  status,
  subject_name,
  college_name,
  branch_name,
  semester_name,
  class_number
FROM professor_attendance 
ORDER BY date DESC, student_roll_number 
LIMIT 5;

-- 1.5: Create safety backup (CRITICAL!)
CREATE TABLE professor_attendance_backup_step1 AS 
SELECT * FROM professor_attendance;

-- 1.6: Verify backup was created successfully
SELECT 
  'BACKUP VERIFICATION' as step,
  'Original Table' as source, 
  COUNT(*) as record_count
FROM professor_attendance
UNION ALL
SELECT 
  'BACKUP VERIFICATION' as step,
  'Backup Table' as source, 
  COUNT(*) as record_count
FROM professor_attendance_backup_step1;

-- 1.7: Check for any data quality issues
SELECT 
  'DATA QUALITY CHECK' as step,
  'Invalid Status Values' as issue_type,
  COUNT(*) as problem_count
FROM professor_attendance 
WHERE status NOT IN ('present', 'absent')
UNION ALL
SELECT 
  'DATA QUALITY CHECK' as step,
  'Missing Required Fields' as issue_type,
  COUNT(*) as problem_count
FROM professor_attendance 
WHERE class_id IS NULL 
   OR student_roll_number IS NULL 
   OR date IS NULL 
   OR status IS NULL
   OR subject_name IS NULL;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ STEP 1 COMPLETED SUCCESSFULLY!';
  RAISE NOTICE '📊 Current system verified and backed up';
  RAISE NOTICE '🛡️ Backup table: professor_attendance_backup_step1';
  RAISE NOTICE '🚀 Ready for Step 2: Create optimized table';
END $$;