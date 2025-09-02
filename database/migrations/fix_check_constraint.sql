-- Check what constraints exist on class_assignment_marks table
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'class_assignment_marks'::regclass
  AND contype = 'c';

-- If there's a constraint preventing decimal marks, we need to drop it
-- Common constraint that might cause this: marks must be integer
-- DROP CONSTRAINT IF EXISTS class_assignment_marks_check;

-- Alternative: Check if marks column has integer constraint
SELECT 
    column_name,
    data_type,
    numeric_precision,
    numeric_scale
FROM information_schema.columns 
WHERE table_name = 'class_assignment_marks' 
  AND column_name = 'marks';
