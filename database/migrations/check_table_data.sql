-- Check if the normalized tables have data and diagnose the view issue

-- 1. Check if the new tables exist and have data
SELECT 'class_assignments table' as table_name, COUNT(*) as row_count FROM class_assignments;
SELECT 'student_marks table' as table_name, COUNT(*) as row_count FROM student_marks;
SELECT 'backup table' as table_name, COUNT(*) as row_count FROM class_assignment_marks_backup;

-- 2. Show actual data in the new tables
SELECT 'class_assignments data' as info, * FROM class_assignments LIMIT 5;
SELECT 'student_marks data' as info, * FROM student_marks LIMIT 5;

-- 3. Test the view directly
SELECT 'view test' as info, COUNT(*) as view_count FROM class_assignment_marks_view;
SELECT 'main view test' as info, COUNT(*) as main_view_count FROM class_assignment_marks;

-- 4. Check if there's a JOIN issue
SELECT 'join test' as info, 
       ca.assignment_name, 
       sm.student_name, 
       sm.marks
FROM class_assignments ca
LEFT JOIN student_marks sm ON ca.id = sm.assignment_id
LIMIT 5;
