-- Fix midsem trigger issues with enhanced debugging

CREATE OR REPLACE FUNCTION notify_midsem_marks_updated()
RETURNS TRIGGER AS $$
DECLARE
  student_profile_id uuid;
  supabase_url text := 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
  service_role_key text := 'your-service-role-key'; -- REPLACE WITH ACTUAL KEY
  response_data text;
  exam_display_name text;
BEGIN
  -- Debug: Log trigger execution
  RAISE NOTICE 'MIDSEM TRIGGER FIRED: Assignment=%, Marks=%, Student=%, StudentID=%', 
    NEW.assignment_name, NEW.marks, NEW.student_name, NEW.student_id;
  
  -- Debug: Log OLD values
  IF OLD IS NOT NULL THEN
    RAISE NOTICE 'MIDSEM TRIGGER OLD: Marks=%, Assignment=%', OLD.marks, OLD.assignment_name;
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: OLD is NULL (INSERT operation)';
  END IF;
  
  -- Check conditions step by step
  IF NEW.marks IS NOT NULL THEN
    RAISE NOTICE 'MIDSEM TRIGGER: ✓ NEW.marks is not null: %', NEW.marks;
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: ✗ NEW.marks is null';
    RETURN NEW;
  END IF;
  
  IF (OLD IS NULL OR OLD.marks IS NULL OR OLD.marks != NEW.marks) THEN
    RAISE NOTICE 'MIDSEM TRIGGER: ✓ Marks condition met';
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: ✗ Marks condition failed - no change detected';
    RETURN NEW;
  END IF;
  
  IF NEW.assignment_name LIKE 'Midsem:%' THEN
    RAISE NOTICE 'MIDSEM TRIGGER: ✓ Assignment is midsem: %', NEW.assignment_name;
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: ✗ Assignment is not midsem: %', NEW.assignment_name;
    RETURN NEW;
  END IF;
  
  RAISE NOTICE 'MIDSEM TRIGGER: All conditions met - processing notification';
  
  -- Enhanced student profile lookup with debugging
  RAISE NOTICE 'MIDSEM TRIGGER: Looking up student - ClassID=%, StudentID=%, StudentRoll=%', 
    NEW.class_id, NEW.student_id, NEW.student_roll;
  
  SELECT cr.student_profile_id INTO student_profile_id
  FROM class_rosters cr
  WHERE cr.class_id = NEW.class_id 
  AND (
    (cr.student_profile_id IS NOT NULL AND cr.student_profile_id::text = NEW.student_id) 
    OR (NEW.student_roll IS NOT NULL AND cr.roll_number = NEW.student_roll)
  )
  AND cr.student_profile_id IS NOT NULL
  LIMIT 1;
  
  IF student_profile_id IS NOT NULL THEN
    RAISE NOTICE 'MIDSEM TRIGGER: ✓ Found student profile: %', student_profile_id;
  ELSE
    RAISE NOTICE 'MIDSEM TRIGGER: ✗ No student profile found';
    
    -- Debug: Show what's in class_rosters for this class
    RAISE NOTICE 'MIDSEM TRIGGER: Checking class_rosters for class_id: %', NEW.class_id;
    FOR student_profile_id IN 
      SELECT cr.student_profile_id 
      FROM class_rosters cr 
      WHERE cr.class_id = NEW.class_id 
      LIMIT 5
    LOOP
      RAISE NOTICE 'MIDSEM TRIGGER: Found roster entry with profile_id: %', student_profile_id;
    END LOOP;
    
    RETURN NEW;
  END IF;
  
  BEGIN
    -- Extract exam name without "Midsem:" prefix for display
    exam_display_name := TRIM(SUBSTRING(NEW.assignment_name FROM 8));
    
    RAISE NOTICE 'MIDSEM TRIGGER: Calling Edge function - URL=%, StudentID=%', 
      supabase_url || '/functions/v1/send-fcm-notification', student_profile_id;
    
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
    
    RAISE NOTICE 'MIDSEM TRIGGER: ✓ Edge function called successfully - Response: %', 
      SUBSTRING(response_data FROM 1 FOR 100);
    
    -- Log successful notification
    RAISE NOTICE 'Midsem marks notification sent for student % - Exam: % - Marks: %/%', 
      NEW.student_name, exam_display_name, NEW.marks, NEW.max_marks;
      
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'MIDSEM TRIGGER: ✗ Failed to send notification: %', SQLERRM;
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
