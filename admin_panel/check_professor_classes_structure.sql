-- Check current structure of professor_classes table
-- Run this query in your Supabase SQL editor to see the actual columns:

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'professor_classes'
ORDER BY ordinal_position;

-- Alternative query to check table structure:
\d professor_classes

-- If the table has professor_email column, we need to either:
-- OPTION 1: Add user_id column and migrate data
-- OPTION 2: Revert our changes to use professor_email consistently

-- OPTION 1: Add user_id column (recommended)
-- First, let's add the user_id column:
ALTER TABLE professor_classes 
ADD COLUMN IF NOT EXISTS user_id uuid;

-- Add foreign key constraint to link with auth.users
ALTER TABLE professor_classes 
ADD CONSTRAINT professor_classes_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_professor_classes_user_id 
ON professor_classes (user_id);

-- If you want to migrate existing data from professor_email to user_id:
-- UPDATE professor_classes 
-- SET user_id = (SELECT id FROM auth.users WHERE email = professor_classes.professor_email)
-- WHERE user_id IS NULL AND professor_email IS NOT NULL;

-- OPTION 2: If you prefer to keep professor_email (simpler approach)
-- Just uncomment the line below and run it:
-- SELECT 'Keep using professor_email - we will revert the JS changes';

-- Check if migration is needed:
SELECT 
  COUNT(*) as total_classes,
  COUNT(user_id) as classes_with_user_id,
  COUNT(professor_email) as classes_with_email
FROM professor_classes;
