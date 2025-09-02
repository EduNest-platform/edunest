-- Clean up duplicate midsem records with incorrect student_id (roll numbers instead of profile IDs)
-- This will remove records where student_id is a roll number format instead of UUID

-- First, let's see what we're dealing with (optional - for verification)
-- SELECT 
--   id, 
--   student_id, 
--   student_name, 
--   student_roll, 
--   assignment_name,
--   marks,
--   created_at
-- FROM class_assignment_marks 
-- WHERE assignment_name LIKE 'Midsem:%'
-- ORDER BY assignment_name, student_name, created_at;

-- Delete duplicate records where student_id looks like a roll number (not UUID format)
-- Keep only records where student_id is a proper UUID (36 characters with hyphens)
DELETE FROM class_assignment_marks 
WHERE assignment_name LIKE 'Midsem:%'
  AND LENGTH(student_id) < 36  -- Roll numbers are shorter than UUIDs
  AND student_id NOT SIMILAR TO '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'; -- Not UUID format

-- Alternative approach: Delete records where student_id matches roll_number pattern
-- DELETE FROM class_assignment_marks 
-- WHERE assignment_name LIKE 'Midsem:%'
--   AND student_id SIMILAR TO '[0-9]+/[0-9]+'; -- Matches roll number pattern like "100/25"

-- Verify cleanup (optional)
-- SELECT 
--   COUNT(*) as remaining_records,
--   COUNT(DISTINCT student_id) as unique_students
-- FROM class_assignment_marks 
-- WHERE assignment_name LIKE 'Midsem:%';
