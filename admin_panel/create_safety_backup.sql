-- Create Safety Backup Before Any Changes
-- Always backup before making any modifications

-- 1. Create backup table with timestamp
CREATE TABLE professor_attendance_backup_20250823 AS 
SELECT * FROM professor_attendance;

-- 2. Verify backup was created successfully
SELECT 
  'BACKUP VERIFICATION' as check_type,
  'Original Table' as source, 
  COUNT(*) as record_count,
  MIN(date) as earliest_date,
  MAX(date) as latest_date
FROM professor_attendance
UNION ALL
SELECT 
  'BACKUP VERIFICATION' as check_type,
  'Backup Table' as source, 
  COUNT(*) as record_count,
  MIN(date) as earliest_date,
  MAX(date) as latest_date
FROM professor_attendance_backup_20250823;

-- 3. Verify data integrity in backup
SELECT 
  'BACKUP INTEGRITY' as check_type,
  CASE 
    WHEN orig.record_count = backup.record_count THEN '✅ BACKUP COMPLETE'
    ELSE '❌ BACKUP INCOMPLETE'
  END as status,
  orig.record_count as original_count,
  backup.record_count as backup_count
FROM (
  SELECT COUNT(*) as record_count FROM professor_attendance
) orig
CROSS JOIN (
  SELECT COUNT(*) as record_count FROM professor_attendance_backup_20250823
) backup;

-- 4. Create restore script (for emergency use)
DO $$
BEGIN
  RAISE NOTICE '=== EMERGENCY RESTORE INSTRUCTIONS ===';
  RAISE NOTICE 'If you need to restore from backup, run:';
  RAISE NOTICE 'DROP TABLE professor_attendance;';
  RAISE NOTICE 'ALTER TABLE professor_attendance_backup_20250823 RENAME TO professor_attendance;';
  RAISE NOTICE '======================================';
END $$;

-- 5. Set backup table permissions (read-only)
REVOKE ALL ON professor_attendance_backup_20250823 FROM PUBLIC;
GRANT SELECT ON professor_attendance_backup_20250823 TO postgres;

-- Success message
SELECT 
  'BACKUP STATUS' as check_type,
  '✅ SAFETY BACKUP CREATED SUCCESSFULLY' as message,
  'professor_attendance_backup_20250823' as backup_table_name,
  NOW() as backup_timestamp;