-- Migration Verification Script
-- Run this to check if the database normalization migration completed successfully

-- 1. Check if new tables exist
SELECT 'Tables Created' as check_type, 
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'class_assignments') 
            AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'student_marks')
       THEN '✅ PASS - Both tables created'
       ELSE '❌ FAIL - Tables missing'
       END as result;

-- 2. Check if backup table exists
SELECT 'Backup Table' as check_type,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'class_assignment_marks_backup')
       THEN '✅ PASS - Backup table created'
       ELSE '❌ FAIL - Backup table missing'
       END as result;

-- 3. Check if view exists
SELECT 'Compatibility View' as check_type,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'class_assignment_marks')
       THEN '✅ PASS - View created'
       ELSE '❌ FAIL - View missing'
       END as result;

-- 4. Check data migration integrity
WITH original_count AS (
  SELECT COUNT(*) as count FROM class_assignment_marks_backup
),
migrated_count AS (
  SELECT COUNT(*) as count FROM student_marks
),
assignments_count AS (
  SELECT COUNT(*) as count FROM class_assignments
)
SELECT 'Data Migration' as check_type,
       CASE WHEN o.count = m.count AND a.count > 0
       THEN '✅ PASS - All ' || o.count || ' records migrated, ' || a.count || ' assignments created'
       ELSE '❌ FAIL - Original: ' || o.count || ', Migrated: ' || m.count || ', Assignments: ' || a.count
       END as result
FROM original_count o, migrated_count m, assignments_count a;

-- 5. Check specific data from your existing records
SELECT 'Sample Data Check' as check_type,
       CASE WHEN EXISTS (
         SELECT 1 FROM class_assignments 
         WHERE assignment_name = 'Assignment 1' 
         AND subject_name = 'Operational Research'
       )
       THEN '✅ PASS - Assignment 1 found in class_assignments'
       ELSE '❌ FAIL - Assignment 1 not found'
       END as result;

-- 6. Check if students migrated correctly
SELECT 'Student Data Check' as check_type,
       CASE WHEN EXISTS (
         SELECT 1 FROM student_marks sm
         JOIN class_assignments ca ON sm.assignment_id = ca.id
         WHERE ca.assignment_name = 'Assignment 1'
         AND sm.student_name = 'Rohit Kumar'
       )
       THEN '✅ PASS - Student marks linked correctly'
       ELSE '❌ FAIL - Student marks not linked'
       END as result;

-- 7. Check view compatibility (should return same data as original)
SELECT 'View Compatibility' as check_type,
       CASE WHEN (SELECT COUNT(*) FROM class_assignment_marks) = 
                 (SELECT COUNT(*) FROM class_assignment_marks_backup)
       THEN '✅ PASS - View returns same record count as original'
       ELSE '❌ FAIL - View record count mismatch'
       END as result;

-- 8. Show detailed counts
SELECT 'Detailed Counts' as info_type,
       'class_assignments: ' || (SELECT COUNT(*) FROM class_assignments) ||
       ', student_marks: ' || (SELECT COUNT(*) FROM student_marks) ||
       ', backup: ' || (SELECT COUNT(*) FROM class_assignment_marks_backup) ||
       ', view: ' || (SELECT COUNT(*) FROM class_assignment_marks) as details;

-- 9. Show sample migrated data
SELECT 'Sample Migrated Data' as info_type, 
       ca.assignment_name, 
       sm.student_name, 
       sm.marks,
       ca.assignment_type
FROM class_assignments ca
JOIN student_marks sm ON ca.id = sm.assignment_id
LIMIT 3;
