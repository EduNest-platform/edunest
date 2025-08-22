-- Clean up excessive monitoring data
-- Keep only the last 24 hours of data to prevent table bloat

-- Delete old monitoring data (keep last 24 hours)
DELETE FROM system_monitoring 
WHERE timestamp < NOW() - INTERVAL '24 hours';

-- Alternative: Keep only the last 100 records
-- DELETE FROM system_monitoring 
-- WHERE id NOT IN (
--   SELECT id FROM system_monitoring 
--   ORDER BY timestamp DESC 
--   LIMIT 100
-- );

-- Show remaining record count
SELECT COUNT(*) as remaining_records, 
       MIN(timestamp) as oldest_record,
       MAX(timestamp) as newest_record
FROM system_monitoring;

-- Create a function to automatically clean up old data
CREATE OR REPLACE FUNCTION cleanup_old_monitoring_data()
RETURNS void AS $$
BEGIN
  -- Delete records older than 7 days
  DELETE FROM system_monitoring 
  WHERE timestamp < NOW() - INTERVAL '7 days';
  
  -- Also limit to max 1000 records to prevent runaway growth
  DELETE FROM system_monitoring 
  WHERE id NOT IN (
    SELECT id FROM system_monitoring 
    ORDER BY timestamp DESC 
    LIMIT 1000
  );
END;
$$ LANGUAGE plpgsql;

-- You can run this manually or set up a cron job:
-- SELECT cleanup_old_monitoring_data();
