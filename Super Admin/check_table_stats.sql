-- Check actual data in feedback_data table
-- Run these queries in Supabase SQL Editor to verify

-- 1. Check total row count
SELECT COUNT(*) as total_rows FROM feedback_data;

-- 2. Check row count by type
SELECT type, COUNT(*) as count 
FROM feedback_data 
GROUP BY type;

-- 3. Check actual data size vs table size
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE tablename = 'feedback_data';

-- 4. Check table size breakdown
SELECT 
    pg_size_pretty(pg_total_relation_size('feedback_data')) as total_size,
    pg_size_pretty(pg_relation_size('feedback_data')) as table_size,
    pg_size_pretty(pg_total_relation_size('feedback_data') - pg_relation_size('feedback_data')) as index_size;

-- 5. Show all data (should be empty if 0 rows)
SELECT id, type, semester, created_at FROM feedback_data ORDER BY created_at DESC;

-- 6. Check indexes on the table
SELECT 
    indexname, 
    indexdef,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
FROM pg_indexes 
WHERE tablename = 'feedback_data';
