-- Fix notification decimal formatting to show clean numbers (remove .00 for whole numbers)

-- Helper function to format decimal numbers cleanly
CREATE OR REPLACE FUNCTION format_clean_decimal(num NUMERIC)
RETURNS TEXT AS $$
BEGIN
  -- If the number is a whole number, return without decimal places
  IF num = FLOOR(num) THEN
    RETURN FLOOR(num)::TEXT;
  ELSE
    -- Otherwise, return with decimal places but remove trailing zeros
    RETURN TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM num::TEXT));
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Update assignment marks notification trigger with clean decimal formatting
CREATE OR REPLACE FUNCTION notify_assignment_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
  service_role_key text := 'your-service-role-key'; -- REPLACE WITH ACTUAL KEY
  response_data text;
BEGIN
  -- Check if marks were updated and it's not a midsem assignment
  IF NEW.marks IS NOT NULL 
     AND (OLD IS NULL OR OLD.marks IS NULL OR OLD.marks != NEW.marks) 
     AND (NEW.assignment_name IS NULL OR NEW.assignment_name NOT LIKE 'Midsem:%') THEN
    
    -- Get student profile ID from class roster
    SELECT cr.student_profile_id INTO student_profile_id
    FROM class_rosters cr
    WHERE cr.class_id = NEW.class_id 
    AND (
      (cr.student_profile_id IS NOT NULL AND cr.student_profile_id::text = NEW.student_id) 
      OR cr.roll_number = NEW.student_roll
    )
    AND cr.student_profile_id IS NOT NULL
    LIMIT 1;
    
    IF student_profile_id IS NOT NULL THEN
      BEGIN
        -- Call Edge Function to send FCM notification with clean decimal formatting
        SELECT content INTO response_data
        FROM http((
          'POST',
          supabase_url || '/functions/v1/send-fcm-notification',
          ARRAY[
            http_header('Content-Type', 'application/json'),
            http_header('Authorization', 'Bearer ' || service_role_key)
          ],
          'application/json',
          json_build_object(
            'studentIds', json_build_array(student_profile_id),
            'title', 'New Assignment Grade 📝',
            'body', format('You received %s/%s marks in %s', 
              format_clean_decimal(NEW.marks), 
              format_clean_decimal(NEW.max_marks), 
              NEW.assignment_name
            ),
            'type', 'assignment_marks',
            'data', json_build_object(
              'type', 'assignment_marks',
              'assignment_name', NEW.assignment_name,
              'marks', NEW.marks,
              'max_marks', NEW.max_marks,
              'subject', COALESCE(NEW.subject_name, 'Unknown Subject'),
              'class_id', NEW.class_id,
              'student_id', student_profile_id
            )
          )::text
        ));
        
        -- Log successful notification
        RAISE NOTICE 'Assignment marks notification sent for student % - Assignment: % - Marks: %/%', 
          NEW.student_name, NEW.assignment_name, NEW.marks, NEW.max_marks;
          
      EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the transaction
        RAISE WARNING 'Failed to send assignment marks notification: %', SQLERRM;
      END;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update midsem marks notification trigger with clean decimal formatting
CREATE OR REPLACE FUNCTION notify_midsem_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
  service_role_key text := 'your-service-role-key'; -- REPLACE WITH ACTUAL KEY
  response_data text;
  exam_display_name text;
BEGIN
  -- Check if marks were updated and it's a midsem assignment
  IF NEW.marks IS NOT NULL 
     AND (OLD IS NULL OR OLD.marks IS NULL OR OLD.marks != NEW.marks) 
     AND NEW.assignment_name LIKE 'Midsem:%' THEN
    
    -- Get student profile ID from class roster
    SELECT cr.student_profile_id INTO student_profile_id
    FROM class_rosters cr
    WHERE cr.class_id = NEW.class_id 
    AND (
      (cr.student_profile_id IS NOT NULL AND cr.student_profile_id::text = NEW.student_id) 
      OR cr.roll_number = NEW.student_roll
    )
    AND cr.student_profile_id IS NOT NULL
    LIMIT 1;
    
    IF student_profile_id IS NOT NULL THEN
      BEGIN
        -- Extract exam name without "Midsem:" prefix for display
        exam_display_name := TRIM(SUBSTRING(NEW.assignment_name FROM 8));
        
        -- Call Edge Function to send FCM notification with clean decimal formatting
        SELECT content INTO response_data
        FROM http((
          'POST',
          supabase_url || '/functions/v1/send-fcm-notification',
          ARRAY[
            http_header('Content-Type', 'application/json'),
            http_header('Authorization', 'Bearer ' || service_role_key)
          ],
          'application/json',
          json_build_object(
            'studentIds', json_build_array(student_profile_id),
            'title', 'Midsem Results Available 🎯',
            'body', format('You scored %s/%s in %s', 
              format_clean_decimal(NEW.marks), 
              format_clean_decimal(NEW.max_marks), 
              exam_display_name
            ),
            'type', 'midsem_marks',
            'data', json_build_object(
              'type', 'midsem_marks',
              'exam_name', NEW.assignment_name,
              'exam_display_name', exam_display_name,
              'marks', NEW.marks,
              'max_marks', NEW.max_marks,
              'subject', COALESCE(NEW.subject_name, 'Unknown Subject'),
              'class_id', NEW.class_id,
              'student_id', student_profile_id
            )
          )::text
        ));
        
        -- Log successful notification
        RAISE NOTICE 'Midsem marks notification sent for student % - Exam: % - Marks: %/%', 
          NEW.student_name, exam_display_name, NEW.marks, NEW.max_marks;
          
      EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the transaction
        RAISE WARNING 'Failed to send midsem marks notification: %', SQLERRM;
      END;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION format_clean_decimal(NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION notify_assignment_marks_updated() TO service_role;
GRANT EXECUTE ON FUNCTION notify_midsem_marks_updated() TO service_role;
