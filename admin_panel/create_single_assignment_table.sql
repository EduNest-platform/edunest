-- Single table approach for assignment marks
-- This table stores both assignment info and student marks in one place

CREATE TABLE IF NOT EXISTS public.class_assignment_marks (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    class_id uuid NOT NULL, -- Reference to professor_classes.id
    assignment_name text NOT NULL, -- e.g., "Assignment 1", "Mid Term", "Project"
    assignment_description text,
    max_marks integer NOT NULL CHECK (max_marks > 0),
    due_date date,
    student_id text NOT NULL, -- profile_id or manual student ID from class_rosters
    student_name text NOT NULL, -- Store student name for easy access
    student_roll text, -- Roll number
    student_email text, -- Email
    marks numeric(5,2) CHECK (marks >= 0 AND marks <= max_marks), -- Actual marks (can be null if not graded)
    graded_at timestamp with time zone,
    graded_by uuid, -- Professor who graded
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    UNIQUE(class_id, assignment_name, student_id) -- Prevent duplicate entries
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_class_id ON public.class_assignment_marks(class_id);
CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_assignment ON public.class_assignment_marks(class_id, assignment_name);
CREATE INDEX IF NOT EXISTS idx_class_assignment_marks_student ON public.class_assignment_marks(student_id);

-- Enable RLS
ALTER TABLE public.class_assignment_marks ENABLE ROW LEVEL SECURITY;

-- RLS Policies - professors can only access marks for their classes
CREATE POLICY "Professors can manage marks for their classes" ON public.class_assignment_marks
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.professor_classes pc
            WHERE pc.id = class_assignment_marks.class_id
            AND pc.professor_email = (
                SELECT email FROM auth.users WHERE id = auth.uid()
            )
        )
    );

-- Add comment
COMMENT ON TABLE public.class_assignment_marks IS 'Single table storing assignment details and student marks for each class';
