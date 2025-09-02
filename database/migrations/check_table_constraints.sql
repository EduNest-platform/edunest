-- Check constraints on class_assignment_marks table
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'class_assignment_marks'::regclass
  AND contype = 'c';

-- Check the table structure
\d class_assignment_marks;
