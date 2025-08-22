-- Fix RLS policies for feedback_data table
-- Allow access with anon key for Super Admin operations

-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated users to read feedback data" ON public.feedback_data;
DROP POLICY IF EXISTS "Allow authenticated users to insert feedback data" ON public.feedback_data;
DROP POLICY IF EXISTS "Allow authenticated users to update feedback data" ON public.feedback_data;
DROP POLICY IF EXISTS "Allow authenticated users to delete feedback data" ON public.feedback_data;

-- Create new policies that allow both authenticated and anonymous access
-- This is needed for Super Admin panel operations

-- Policy for reading feedback data (allow all)
CREATE POLICY "Allow read access to feedback data" ON public.feedback_data
    FOR SELECT USING (true);

-- Policy for inserting feedback data (allow all)
CREATE POLICY "Allow insert access to feedback data" ON public.feedback_data
    FOR INSERT WITH CHECK (true);

-- Policy for updating feedback data (allow all)
CREATE POLICY "Allow update access to feedback data" ON public.feedback_data
    FOR UPDATE USING (true);

-- Policy for deleting feedback data (allow all)
CREATE POLICY "Allow delete access to feedback data" ON public.feedback_data
    FOR DELETE USING (true);

-- Alternative: If you want to be more restrictive, you can use this instead:
-- This allows both authenticated users and anon key access

/*
-- More restrictive policies (uncomment if you prefer this approach)
CREATE POLICY "Allow authenticated and anon read access" ON public.feedback_data
    FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Allow authenticated and anon insert access" ON public.feedback_data
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Allow authenticated and anon update access" ON public.feedback_data
    FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Allow authenticated and anon delete access" ON public.feedback_data
    FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'anon');
*/
