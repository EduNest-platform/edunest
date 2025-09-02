-- Debug script to check notification triggers and test midsem notifications

-- 1. Check if triggers exist
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name IN ('trigger_assignment_marks_notification', 'trigger_midsem_marks_notification');

-- 2. Check if functions exist
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name IN ('notify_assignment_marks_updated', 'notify_midsem_marks_updated');

-- 3. Test trigger by manually updating a midsem record (this should fire notification)
-- Replace the ID with an actual midsem record ID from your data
UPDATE class_assignment_marks 
SET marks = marks + 0.01  -- Small change to trigger notification
WHERE assignment_name LIKE 'Midsem:%' 
  AND student_id = '3e5d56aa-6b23-4d4d-bb25-6a6cfd6dbbe2'
  AND id = '512847f3-c4fb-43e8-941e-0ac481167a26'  -- Replace with actual ID
RETURNING id, assignment_name, marks, student_name;

-- 4. Check recent midsem records to verify data structure
SELECT 
    id,
    assignment_name,
    student_id,
    student_name,
    student_email,
    marks,
    graded_at,
    created_at
FROM class_assignment_marks 
WHERE assignment_name LIKE 'Midsem:%'
ORDER BY graded_at DESC 
LIMIT 5;

-- 5. Check if student profile exists in class roster (required for notification)
SELECT 
    cr.student_profile_id,
    cr.student_name,
    cr.student_email,
    cr.roll_number
FROM class_rosters cr
WHERE cr.class_id = '6b6307c2-a3f3-4b85-9616-ccb6e5131e3c'
  AND cr.student_profile_id = '3e5d56aa-6b23-4d4d-bb25-6a6cfd6dbbe2';
