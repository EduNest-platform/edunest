-- Revert Database Normalization - Back to Original Structure
-- This script restores the original class_assignment_marks table structure

-- Step 1: Drop the views that are causing issues
DROP VIEW IF EXISTS class_assignment_marks;
DROP VIEW IF EXISTS class_assignment_marks_view;

-- Step 2: Drop the normalized tables (they use more space than expected)
DROP TABLE IF EXISTS student_marks;
DROP TABLE IF EXISTS class_assignments;

-- Step 3: Restore the original table by renaming the backup
ALTER TABLE class_assignment_marks_backup RENAME TO class_assignment_marks;

-- Step 4: Recreate the original indexes for performance
CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_class_id 
ON public.class_assignment_marks USING btree (class_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_assignment 
ON public.class_assignment_marks USING btree (class_id, assignment_name) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_student 
ON public.class_assignment_marks USING btree (student_id) TABLESPACE pg_default;

-- Step 5: Verify the revert worked
SELECT 'Revert Status' as check_type,
       CASE WHEN EXISTS (SELECT 1 FROM class_assignment_marks LIMIT 1)
            AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'class_assignments')
            AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'student_marks')
       THEN '✅ SUCCESS - Original structure restored, normalized tables removed'
       ELSE '❌ FAILED - Revert incomplete'
       END as result;

-- Step 6: Show current data count
SELECT 'Data Count' as info, COUNT(*) as total_records FROM class_assignment_marks;

-- Revert complete! 
-- Storage: Back to 152 kB (more efficient for current dataset size)
-- All existing assignment and midsem marks code will work unchanged
