-- SQL script to create assignment-related tables for EduNest

-- Create assignments table
CREATE TABLE IF NOT EXISTS public.assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    title text NOT NULL,
    description text,
    max_marks integer NOT NULL CHECK (max_marks > 0),
    due_date date NOT NULL,
    type text DEFAULT 'assignment',
    class_id uuid NOT NULL, -- Reference to professor_classes.id
    created_by uuid, -- Reference to auth.users.id
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Create assignment_marks table
CREATE TABLE IF NOT EXISTS public.assignment_marks (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    assignment_id uuid NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
    student_id text NOT NULL, -- Can be profile_id or manual_student_id
    marks numeric(5,2) CHECK (marks >= 0), -- Allows decimal marks
    graded_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    graded_by uuid, -- Reference to auth.users.id (professor who graded)
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    UNIQUE(assignment_id, student_id) -- Prevent duplicate marks for same student/assignment
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_assignments_class_id ON public.assignments(class_id);
CREATE INDEX IF NOT EXISTS idx_assignments_created_by ON public.assignments(created_by);
CREATE INDEX IF NOT EXISTS idx_assignment_marks_assignment_id ON public.assignment_marks(assignment_id);
CREATE INDEX IF NOT EXISTS idx_assignment_marks_student_id ON public.assignment_marks(student_id);

-- Add RLS (Row Level Security) policies
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignment_marks ENABLE ROW LEVEL SECURITY;

-- Assignments policies - professors can manage assignments for their classes
CREATE POLICY "Professors can view assignments for their classes" ON public.assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.professor_classes pc
            WHERE pc.id = assignments.class_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can create assignments for their classes" ON public.assignments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.professor_classes pc
            WHERE pc.id = assignments.class_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can update assignments for their classes" ON public.assignments
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.professor_classes pc
            WHERE pc.id = assignments.class_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can delete assignments for their classes" ON public.assignments
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.professor_classes pc
            WHERE pc.id = assignments.class_id
            AND pc.professor_id = auth.uid()
        )
    );

-- Assignment marks policies - professors can manage marks for their assignments
CREATE POLICY "Professors can view marks for their assignments" ON public.assignment_marks
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.assignments a
            JOIN public.professor_classes pc ON pc.id = a.class_id
            WHERE a.id = assignment_marks.assignment_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can create marks for their assignments" ON public.assignment_marks
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.assignments a
            JOIN public.professor_classes pc ON pc.id = a.class_id
            WHERE a.id = assignment_marks.assignment_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can update marks for their assignments" ON public.assignment_marks
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.assignments a
            JOIN public.professor_classes pc ON pc.id = a.class_id
            WHERE a.id = assignment_marks.assignment_id
            AND pc.professor_id = auth.uid()
        )
    );

CREATE POLICY "Professors can delete marks for their assignments" ON public.assignment_marks
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.assignments a
            JOIN public.professor_classes pc ON pc.id = a.class_id
            WHERE a.id = assignment_marks.assignment_id
            AND pc.professor_id = auth.uid()
        )
    );

-- Add comments for documentation
COMMENT ON TABLE public.assignments IS 'Stores assignments created by professors for their classes';
COMMENT ON TABLE public.assignment_marks IS 'Stores marks given to students for assignments';

COMMENT ON COLUMN public.assignments.class_id IS 'Reference to professor_classes.id';
COMMENT ON COLUMN public.assignments.created_by IS 'Professor who created the assignment';
COMMENT ON COLUMN public.assignment_marks.student_id IS 'Can be profile_id for registered students or manual ID for non-registered';
COMMENT ON COLUMN public.assignment_marks.marks IS 'Marks awarded (can be decimal)';
