-- Enable the http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;

-- Function to send assignment marks notification
CREATE OR REPLACE FUNCTION notify_assignment_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co'; -- Your actual Supabase URL
  service_role_key text := 'your-service-role-key'; -- Replace with your actual service role key from Supabase Dashboard > Settings > API
  response_data text;
BEGIN
  -- Only trigger for actual mark updates (not null marks) and exclude midsem
  IF NEW.marks IS NOT NULL 
     AND (OLD IS NULL OR OLD.marks IS NULL OR OLD.marks != NEW.marks) 
     AND NEW.assignment_name NOT LIKE 'Midsem:%' THEN
    
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
    
    -- Only send notification if student has a profile (is registered)
    IF student_profile_id IS NOT NULL THEN
      BEGIN
        -- Call Edge Function to send FCM notification
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
            'body', format('You received %s/%s marks in %s', NEW.marks, NEW.max_marks, NEW.assignment_name),
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

-- Function to send midsem marks notification
CREATE OR REPLACE FUNCTION notify_midsem_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co'; -- Your actual Supabase URL
  service_role_key text := 'your-service-role-key'; -- Replace with your actual service role key from Supabase Dashboard > Settings > API
  response_data text;
  exam_display_name text;
BEGIN
  -- Only trigger for actual mark updates (not null marks) and only for midsem
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
    
    -- Only send notification if student has a profile (is registered)
    IF student_profile_id IS NOT NULL THEN
      BEGIN
        -- Extract exam name without "Midsem:" prefix for display
        exam_display_name := TRIM(SUBSTRING(NEW.assignment_name FROM 8)); -- Remove "Midsem: " prefix
        
        -- Call Edge Function to send FCM notification
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
            'body', format('You scored %s/%s in %s', NEW.marks, NEW.max_marks, exam_display_name),
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

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_assignment_marks_notification ON class_assignment_marks;
DROP TRIGGER IF EXISTS trigger_midsem_marks_notification ON class_assignment_marks;

-- Create trigger for assignment marks (excludes midsem)
CREATE TRIGGER trigger_assignment_marks_notification
  AFTER INSERT OR UPDATE ON class_assignment_marks
  FOR EACH ROW
  WHEN (NEW.assignment_name NOT LIKE 'Midsem:%')
  EXECUTE FUNCTION notify_assignment_marks_updated();

-- Create trigger for midsem marks (only midsem)
CREATE TRIGGER trigger_midsem_marks_notification
  AFTER INSERT OR UPDATE ON class_assignment_marks
  FOR EACH ROW
  WHEN (NEW.assignment_name LIKE 'Midsem:%')
  EXECUTE FUNCTION notify_midsem_marks_updated();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION notify_assignment_marks_updated() TO service_role;
GRANT EXECUTE ON FUNCTION notify_midsem_marks_updated() TO service_role;
