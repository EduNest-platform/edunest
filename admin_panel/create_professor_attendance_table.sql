-- Create professor_attendance table with proper structure
CREATE TABLE IF NOT EXISTS public.professor_attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL,
  student_roll_number text NOT NULL,
  student_name text NOT NULL,
  date date NOT NULL,
  status text NOT NULL,
  subject_name text NOT NULL,
  college_name text NULL,
  branch_name text NULL,
  semester_name text NULL,
  class_number integer NULL DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT professor_attendance_pkey PRIMARY KEY (id),
  CONSTRAINT professor_attendance_unique UNIQUE (class_id, student_roll_number, date, class_number),
  CONSTRAINT professor_attendance_class_id_fkey FOREIGN KEY (class_id) REFERENCES professor_classes (id) ON DELETE CASCADE,
  CONSTRAINT professor_attendance_status_check CHECK (
    status = ANY (ARRAY['present'::text, 'absent'::text])
  )
) TABLESPACE pg_default;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_professor_attendance_class_id 
ON public.professor_attendance USING btree (class_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_professor_attendance_date 
ON public.professor_attendance USING btree (date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_professor_attendance_roll_number 
ON public.professor_attendance USING btree (student_roll_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_professor_attendance_student_date 
ON public.professor_attendance USING btree (student_roll_number, date) TABLESPACE pg_default;

-- Enable Row Level Security
ALTER TABLE public.professor_attendance ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Enable professors to manage their class attendance" ON public.professor_attendance
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM professor_classes 
    WHERE professor_classes.id = professor_attendance.class_id 
    AND professor_classes.user_id = auth.uid()
  )
);

-- Allow students to view their own attendance
CREATE POLICY "Enable students to view their attendance" ON public.professor_attendance
FOR SELECT USING (
  student_roll_number = (
    SELECT roll_number FROM student_profiles 
    WHERE user_id = auth.uid()
  )
);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_professor_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_professor_attendance_updated_at
    BEFORE UPDATE ON public.professor_attendance
    FOR EACH ROW
    EXECUTE FUNCTION update_professor_attendance_updated_at();

-- Insert some sample data for testing (optional)
/*
INSERT INTO public.professor_attendance (
  class_id, 
  student_roll_number, 
  student_name, 
  date, 
  status, 
  subject_name, 
  college_name, 
  branch_name, 
  semester_name,
  class_number
) VALUES 
-- Add sample records here if needed for testing
-- ('your-class-id', 'ROLL001', 'Student Name', '2025-01-15', 'present', 'Mathematics', 'College Name', 'Branch Name', 'Semester 1', 1)
ON CONFLICT (class_id, student_roll_number, date, class_number) DO NOTHING;
*/

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ professor_attendance table created successfully!';
    RAISE NOTICE '📊 Table: professor_attendance with proper indexes and RLS';
    RAISE NOTICE '🔐 RLS policies: professors can manage, students can view their own';
    RAISE NOTICE '🚀 Ready for attendance tracking!';
END $$;
