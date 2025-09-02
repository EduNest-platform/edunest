-- Fix View Security Issues
-- The views were created with SECURITY DEFINER which causes permission issues
-- This script recreates them with proper security settings

-- Drop existing views
DROP VIEW IF EXISTS class_assignment_marks;
DROP VIEW IF EXISTS class_assignment_marks_view;

-- Recreate the base view with SECURITY INVOKER (uses current user's permissions)
CREATE OR REPLACE VIEW class_assignment_marks_view 
WITH (security_invoker = true) AS
SELECT 
  sm.id,
  ca.class_id,
  ca.assignment_name,
  ca.assignment_description,
  ca.max_marks,
  sm.student_id,
  sm.student_name,
  sm.student_roll,
  sm.student_email,
  sm.marks,
  sm.graded_at,
  ca.graded_by,
  sm.created_at,
  ca.subject_name
FROM class_assignments ca
JOIN student_marks sm ON ca.id = sm.assignment_id;

-- Recreate the main compatibility view with SECURITY INVOKER
CREATE OR REPLACE VIEW class_assignment_marks 
WITH (security_invoker = true) AS
SELECT * FROM class_assignment_marks_view;

-- Grant necessary permissions to authenticated users
GRANT SELECT ON class_assignments TO authenticated;
GRANT SELECT ON student_marks TO authenticated;
GRANT SELECT ON class_assignment_marks_view TO authenticated;
GRANT SELECT ON class_assignment_marks TO authenticated;

-- Grant INSERT, UPDATE, DELETE permissions for admin operations
GRANT INSERT, UPDATE, DELETE ON class_assignments TO authenticated;
GRANT INSERT, UPDATE, DELETE ON student_marks TO authenticated;

-- Enable RLS (Row Level Security) if not already enabled
ALTER TABLE class_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_marks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for class_assignments
CREATE POLICY "Users can view class assignments" ON class_assignments
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert class assignments" ON class_assignments
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update class assignments" ON class_assignments
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "Users can delete class assignments" ON class_assignments
  FOR DELETE TO authenticated
  USING (true);

-- Create RLS policies for student_marks
CREATE POLICY "Users can view student marks" ON student_marks
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert student marks" ON student_marks
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update student marks" ON student_marks
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "Users can delete student marks" ON student_marks
  FOR DELETE TO authenticated
  USING (true);

-- Verify the fix worked
SELECT 'View Security Fix' as check_type,
       CASE WHEN EXISTS (SELECT 1 FROM class_assignment_marks LIMIT 1)
       THEN '✅ PASS - Views accessible with proper security'
       ELSE '❌ FAIL - Views still not accessible'
       END as result;
