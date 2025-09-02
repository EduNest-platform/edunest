-- Debug midsem trigger specifically
-- First, let's add some debug logging to the midsem trigger function

CREATE OR REPLACE FUNCTION notify_midsem_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
  service_role_key text := 'your-service-role-key'; -- Replace with actual key
  response_data text;
  exam_display_name text;
BEGIN
  -- Add debug logging
  RAISE NOTICE 'MIDSEM TRIGGER FIRED: Assignment: %, Marks: %, Student: %', 
    NEW.assignment_name, NEW.marks, NEW.student_name;
  
  -- Only trigger for actual mark updates (not null marks) and only for midsem
  IF NEW.marks IS NOT NULL 
     AND (OLD IS NULL OR OLD.marks IS NULL OR OLD.marks != NEW.marks) 
     AND NEW.assignment_name LIKE 'Midsem:%' THEN
    
    RAISE NOTICE 'MIDSEM TRIGGER CONDITIONS MET - Processing notification';
    
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
    
    RAISE NOTICE 'MIDSEM TRIGGER: Found student profile ID: %', student_profile_id;
    
    -- Only send notification if student has a profile (is registered)
    IF student_profile_id IS NOT NULL THEN
      BEGIN
        -- Extract exam name without "Midsem:" prefix for display
        exam_display_name := TRIM(SUBSTRING(NEW.assignment_name FROM 8)); -- Remove "Midsem: " prefix
        
        RAISE NOTICE 'MIDSEM TRIGGER: Calling Edge function for student %', student_profile_id;
        
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
    ELSE
      RAISE NOTICE 'MIDSEM TRIGGER: No student profile found for student_id: %', NEW.student_id;
    END IF;
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: Conditions not met - Marks: %, Assignment: %', NEW.marks, NEW.assignment_name;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
