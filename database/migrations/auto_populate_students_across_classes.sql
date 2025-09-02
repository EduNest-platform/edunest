-- Auto-populate students across classes with same college/branch/semester
-- This function will automatically add students from one class to other classes 
-- with the same college, branch, and semester when a new student is added

-- Drop existing functions and triggers first to avoid conflicts
DROP FUNCTION IF EXISTS sync_students_across_matching_classes(UUID);
DROP FUNCTION IF EXISTS get_matching_classes_for_student_sharing(UUID);
DROP TRIGGER IF EXISTS trg_auto_populate_students ON class_rosters;
DROP TRIGGER IF EXISTS trg_auto_populate_new_class ON professor_classes;

-- Function to auto-populate students across matching classes
CREATE OR REPLACE FUNCTION auto_populate_students_across_classes()
RETURNS TRIGGER AS $$
DECLARE
    matching_class RECORD;
    student_exists BOOLEAN;
BEGIN
    -- Only proceed if this is a new student insertion
    IF TG_OP = 'INSERT' THEN
        -- Find all other classes with same college, branch, and semester
        FOR matching_class IN 
            SELECT DISTINCT pc.id, pc.class_name, pc.subject_name
            FROM professor_classes pc
            WHERE pc.college_name = (
                SELECT college_name 
                FROM professor_classes 
                WHERE id = NEW.class_id
            )
            AND pc.branch_name = (
                SELECT branch_name 
                FROM professor_classes 
                WHERE id = NEW.class_id
            )
            AND pc.semester_name = (
                SELECT semester_name 
                FROM professor_classes 
                WHERE id = NEW.class_id
            )
            AND pc.id != NEW.class_id  -- Exclude the current class
        LOOP
            -- Check if student already exists in this class
            SELECT EXISTS(
                SELECT 1 FROM class_rosters 
                WHERE class_id = matching_class.id 
                AND roll_number = NEW.roll_number
            ) INTO student_exists;
            
            -- If student doesn't exist, add them
            IF NOT student_exists THEN
                INSERT INTO class_rosters (
                    class_id,
                    roll_number,
                    student_name,
                    student_email,
                    is_verified,
                    student_profile_id
                ) VALUES (
                    matching_class.id,
                    NEW.roll_number,
                    NEW.student_name,
                    NEW.student_email,
                    NEW.is_verified,
                    NEW.student_profile_id
                );
                
                -- Log the auto-population
                RAISE NOTICE 'Auto-populated student % (%) to class % (%)', 
                    NEW.student_name, NEW.roll_number, 
                    matching_class.class_name, matching_class.subject_name;
            END IF;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-population
DROP TRIGGER IF EXISTS trg_auto_populate_students ON class_rosters;
CREATE TRIGGER trg_auto_populate_students
    AFTER INSERT ON class_rosters
    FOR EACH ROW
    EXECUTE FUNCTION auto_populate_students_across_classes();


-- Function to auto-populate new classes with existing students
CREATE OR REPLACE FUNCTION auto_populate_new_class_with_students()
RETURNS TRIGGER AS $$
DECLARE
    existing_student RECORD;
    student_exists BOOLEAN;
BEGIN
    -- Only proceed if this is a new class insertion
    IF TG_OP = 'INSERT' THEN
        -- Find all students from existing classes with same college, branch, and semester
        FOR existing_student IN 
            SELECT DISTINCT cr.roll_number, cr.student_name, cr.student_email, 
                   cr.is_verified, cr.student_profile_id
            FROM class_rosters cr
            JOIN professor_classes pc ON cr.class_id = pc.id
            WHERE pc.college_name = NEW.college_name
            AND pc.branch_name = NEW.branch_name
            AND pc.semester_name = NEW.semester_name
            AND pc.id != NEW.id  -- Exclude the current class (shouldn't exist yet, but safety)
        LOOP
            -- Check if student already exists in this new class (shouldn't happen, but safety)
            SELECT EXISTS(
                SELECT 1 FROM class_rosters 
                WHERE class_id = NEW.id 
                AND roll_number = existing_student.roll_number
            ) INTO student_exists;
            
            -- If student doesn't exist, add them to the new class
            IF NOT student_exists THEN
                INSERT INTO class_rosters (
                    class_id,
                    roll_number,
                    student_name,
                    student_email,
                    is_verified,
                    student_profile_id
                ) VALUES (
                    NEW.id,
                    existing_student.roll_number,
                    existing_student.student_name,
                    existing_student.student_email,
                    existing_student.is_verified,
                    existing_student.student_profile_id
                );
                
                -- Log the auto-population
                RAISE NOTICE 'Auto-populated existing student % (%) to new class % (%)', 
                    existing_student.student_name, existing_student.roll_number, 
                    NEW.class_name, NEW.subject_name;
            END IF;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new class auto-population
DROP TRIGGER IF EXISTS trg_auto_populate_new_class ON professor_classes;
CREATE TRIGGER trg_auto_populate_new_class
    AFTER INSERT ON professor_classes
    FOR EACH ROW
    EXECUTE FUNCTION auto_populate_new_class_with_students();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION auto_populate_students_across_classes() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_populate_new_class_with_students() TO authenticated;
