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

-- RLS policies for super admin access
ALTER TABLE system_monitoring ENABLE ROW LEVEL SECURITY;

-- Allow super admins to read all monitoring data (simplified for admin database)
CREATE POLICY "Super admins can read system monitoring" ON system_monitoring
    FOR SELECT
    USING (true); -- Allow all reads in admin database

-- Allow the app to insert monitoring data (from service account or authenticated users)
CREATE POLICY "Allow system monitoring inserts" ON system_monitoring
    FOR INSERT
    WITH CHECK (true); -- Allow all inserts for monitoring data

-- Create a function to automatically clean old monitoring data (keep last 24 hours)
CREATE OR REPLACE FUNCTION cleanup_old_monitoring_data()
RETURNS void AS $$
BEGIN
    DELETE FROM system_monitoring 
    WHERE timestamp < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup to run every hour
SELECT cron.schedule('cleanup_monitoring_data', '0 * * * *', 'SELECT cleanup_old_monitoring_data();');

-- Create exam_sessions table for tracking active exams
CREATE TABLE IF NOT EXISTS exam_sessions (
    id BIGSERIAL PRIMARY KEY,
    exam_id TEXT NOT NULL,
    student_id UUID REFERENCES auth.users(id),
    session_start TIMESTAMPTZ DEFAULT NOW(),
    session_end TIMESTAMPTZ,
    active BOOLEAN DEFAULT TRUE,
    progress JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient exam session queries
CREATE INDEX IF NOT EXISTS idx_exam_sessions_active ON exam_sessions(active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam_id ON exam_sessions(exam_id);

-- RLS for exam sessions
ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;

-- Students can only see their own sessions (simplified for admin database)
CREATE POLICY "Manage exam sessions" ON exam_sessions
    FOR ALL
    USING (true); -- Allow all operations in admin database

-- Create a function to update monitoring stats from Flutter app
CREATE OR REPLACE FUNCTION update_system_monitoring_stats(
    p_active_connections INTEGER,
    p_max_connections INTEGER,
    p_queue_size INTEGER,
    p_system_load DECIMAL,
    p_crash_risk TEXT,
    p_peak_users INTEGER,
    p_cache_hit_rate DECIMAL,
    p_cache_entries INTEGER,
    p_exam_mode_active BOOLEAN DEFAULT FALSE,
    p_active_test_takers INTEGER DEFAULT 0,
    p_active_exams INTEGER DEFAULT 0,
    p_circuit_breaker_open BOOLEAN DEFAULT FALSE,
    p_app_version TEXT DEFAULT NULL,
    p_platform TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS void AS $$
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
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_system_monitoring_stats TO authenticated;

-- Create emergency actions table to track admin interventions
CREATE TABLE IF NOT EXISTS emergency_actions (
    id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL, -- 'throttle', 'clear_queue', 'maintenance_mode', etc.
    performed_by UUID REFERENCES auth.users(id),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    details JSONB,
    success BOOLEAN DEFAULT TRUE
);

-- RLS for emergency actions
ALTER TABLE emergency_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Manage emergency actions" ON emergency_actions
    FOR ALL
    USING (true); -- Allow all operations in admin database

-- Create view for latest system stats
CREATE OR REPLACE VIEW latest_system_stats AS
SELECT DISTINCT ON (1)
    *
FROM system_monitoring
ORDER BY 1, timestamp DESC;

-- Grant access to views
GRANT SELECT ON latest_system_stats TO authenticated;
