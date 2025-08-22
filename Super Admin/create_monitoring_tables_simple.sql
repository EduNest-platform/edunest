-- 🔥 SIMPLIFIED MONITORING TABLES FOR SUPABASE ADMIN DATABASE
-- This version works independently without referencing other tables

-- Create system_monitoring table for real-time stats from Flutter app
CREATE TABLE IF NOT EXISTS system_monitoring (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    active_connections INTEGER NOT NULL DEFAULT 0,
    max_connections INTEGER NOT NULL DEFAULT 60,
    queue_size INTEGER NOT NULL DEFAULT 0,
    system_load DECIMAL(5,2) NOT NULL DEFAULT 0,
    crash_risk TEXT NOT NULL DEFAULT 'LOW',
    peak_users INTEGER NOT NULL DEFAULT 0,
    cache_hit_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    cache_entries INTEGER NOT NULL DEFAULT 0,
    exam_mode_active BOOLEAN DEFAULT FALSE,
    active_test_takers INTEGER DEFAULT 0,
    active_exams INTEGER DEFAULT 0,
    circuit_breaker_open BOOLEAN DEFAULT FALSE,
    app_version TEXT,
    platform TEXT,
    metadata JSONB
);

-- Index for efficient querying
CREATE INDEX IF NOT EXISTS idx_system_monitoring_timestamp ON system_monitoring(timestamp DESC);

-- Create exam_sessions table for tracking individual exam instances
CREATE TABLE IF NOT EXISTS exam_sessions (
    id BIGSERIAL PRIMARY KEY,
    exam_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    start_time TIMESTAMPTZ DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    status TEXT DEFAULT 'active',
    test_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for exam sessions
CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam_id ON exam_sessions(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_student_id ON exam_sessions(student_id);

-- Create emergency_actions table for logging system interventions
CREATE TABLE IF NOT EXISTS emergency_actions (
    id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    admin_id TEXT,
    details JSONB,
    success BOOLEAN DEFAULT TRUE
);

-- RLS for monitoring tables (simplified for admin database)
ALTER TABLE system_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_actions ENABLE ROW LEVEL SECURITY;

-- Simple policies that allow all operations (since this is admin database)
CREATE POLICY "Allow all monitoring operations" ON system_monitoring FOR ALL USING (true);
CREATE POLICY "Allow all exam session operations" ON exam_sessions FOR ALL USING (true);
CREATE POLICY "Allow all emergency action operations" ON emergency_actions FOR ALL USING (true);

-- Function to insert monitoring data from Flutter app
CREATE OR REPLACE FUNCTION insert_monitoring_data(
    p_active_connections INTEGER,
    p_max_connections INTEGER DEFAULT 60,
    p_queue_size INTEGER DEFAULT 0,
    p_system_load DECIMAL DEFAULT 0,
    p_crash_risk TEXT DEFAULT 'LOW',
    p_peak_users INTEGER DEFAULT 0,
    p_cache_hit_rate DECIMAL DEFAULT 0,
    p_cache_entries INTEGER DEFAULT 0,
    p_exam_mode_active BOOLEAN DEFAULT FALSE,
    p_active_test_takers INTEGER DEFAULT 0,
    p_active_exams INTEGER DEFAULT 0,
    p_circuit_breaker_open BOOLEAN DEFAULT FALSE,
    p_app_version TEXT DEFAULT NULL,
    p_platform TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    inserted_id INTEGER;
BEGIN
    INSERT INTO system_monitoring (
        active_connections,
        max_connections,
        queue_size,
        system_load,
        crash_risk,
        peak_users,
        cache_hit_rate,
        cache_entries,
        exam_mode_active,
        active_test_takers,
        active_exams,
        circuit_breaker_open,
        app_version,
        platform,
        metadata
    ) VALUES (
        p_active_connections,
        p_max_connections,
        p_queue_size,
        p_system_load,
        p_crash_risk,
        p_peak_users,
        p_cache_hit_rate,
        p_cache_entries,
        p_exam_mode_active,
        p_active_test_takers,
        p_active_exams,
        p_circuit_breaker_open,
        p_app_version,
        p_platform,
        p_metadata
    ) RETURNING id INTO inserted_id;
    
    RETURN inserted_id;
END;
$$ LANGUAGE plpgsql;

-- Function to clean old monitoring data (keep last 24 hours)
CREATE OR REPLACE FUNCTION cleanup_old_monitoring_data()
RETURNS void AS $$
BEGIN
    DELETE FROM system_monitoring 
    WHERE timestamp < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Function to get latest system stats
CREATE OR REPLACE FUNCTION get_latest_system_stats()
RETURNS TABLE(
    active_connections INTEGER,
    max_connections INTEGER,
    queue_size INTEGER,
    system_load DECIMAL,
    crash_risk TEXT,
    peak_users INTEGER,
    cache_hit_rate DECIMAL,
    cache_entries INTEGER,
    exam_mode_active BOOLEAN,
    active_test_takers INTEGER,
    active_exams INTEGER,
    circuit_breaker_open BOOLEAN,
    last_update TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sm.active_connections,
        sm.max_connections,
        sm.queue_size,
        sm.system_load,
        sm.crash_risk,
        sm.peak_users,
        sm.cache_hit_rate,
        sm.cache_entries,
        sm.exam_mode_active,
        sm.active_test_takers,
        sm.active_exams,
        sm.circuit_breaker_open,
        sm.timestamp as last_update
    FROM system_monitoring sm
    ORDER BY sm.timestamp DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create a view for dashboard queries
CREATE OR REPLACE VIEW dashboard_stats AS
SELECT 
    active_connections,
    max_connections,
    queue_size,
    system_load,
    crash_risk,
    peak_users,
    cache_hit_rate,
    cache_entries,
    exam_mode_active,
    active_test_takers,
    active_exams,
    circuit_breaker_open,
    timestamp as last_update
FROM system_monitoring
ORDER BY timestamp DESC
LIMIT 1;

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Insert initial monitoring data for testing
INSERT INTO system_monitoring (
    active_connections,
    max_connections,
    queue_size,
    system_load,
    crash_risk,
    peak_users,
    cache_hit_rate,
    cache_entries
) VALUES (
    5,
    60,
    0,
    25.5,
    'LOW',
    10,
    75.0,
    25
);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Monitoring tables created successfully!';
    RAISE NOTICE '📊 Tables: system_monitoring, exam_sessions, emergency_actions';
    RAISE NOTICE '🔧 Functions: insert_monitoring_data(), get_latest_system_stats()';
    RAISE NOTICE '📈 View: dashboard_stats';
    RAISE NOTICE '🚀 Ready for monitoring dashboard!';
END $$;
