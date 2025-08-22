import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/scalable_connection_service.dart';
import '../services/exam_optimization_service.dart';
import '../services/free_plan_optimizer_service.dart';

/// Real-time system monitoring dashboard for admins/developers
class SystemMonitoringDashboard extends StatefulWidget {
  final bool showDebugInfo;
  
  const SystemMonitoringDashboard({
    Key? key,
    this.showDebugInfo = false,
  }) : super(key: key);

  @override
  _SystemMonitoringDashboardState createState() => _SystemMonitoringDashboardState();
}

class _SystemMonitoringDashboardState extends State<SystemMonitoringDashboard> {
  Timer? _updateTimer;
  Map<String, dynamic> _systemStats = {};
  Map<String, dynamic> _examStats = {};
  
  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _startMonitoring() {
    _updateStats();
    _updateTimer = Timer.periodic(Duration(seconds: 5), (_) => _updateStats());
  }
  
  void _updateStats() {
    if (mounted) {
      setState(() {
        _systemStats = ScalableConnectionService.getAdvancedStats();
        _examStats = ExamOptimizationService.getExamStats();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.showDebugInfo && !kDebugMode) {
      return SizedBox.shrink(); // Hide in production
    }
    
    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          SizedBox(height: 8),
          _buildConnectionStats(),
          SizedBox(height: 8),
          _buildExamStats(),
          if (widget.showDebugInfo) ...[
            SizedBox(height: 8),
            _buildAdvancedStats(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    final status = _systemStats['system_status'] ?? 'UNKNOWN';
    final crashRisk = _systemStats['crash_risk'] ?? 'UNKNOWN';
    
    return Row(
      children: [
        Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          'System: $status',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Spacer(),
        Text(
          'Risk: $crashRisk',
          style: TextStyle(
            color: _getRiskColor(crashRisk),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildConnectionStats() {
    final active = _systemStats['active_connections'] ?? 0;
    final max = _systemStats['max_connections'] ?? 60;
    final queue = _systemStats['queue_size'] ?? 0;
    final usage = active > 0 ? (active / max * 100).round() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connections: $active/$max ($usage%)',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: active / max,
          backgroundColor: Colors.grey[700],
          valueColor: AlwaysStoppedAnimation(_getUsageColor(usage)),
        ),
        SizedBox(height: 4),
        if (queue > 0)
          Text(
            'Queue: $queue operations waiting',
            style: TextStyle(color: Colors.orange, fontSize: 10),
          ),
      ],
    );
  }
  
  Widget _buildExamStats() {
    final examMode = _examStats['exam_mode_active'] ?? false;
    final activeTakers = _examStats['active_exam_takers'] ?? 0;
    final activeExams = _examStats['active_exams'] ?? 0;
    
    if (!examMode && activeExams == 0) {
      return Text(
        '📚 No active exams',
        style: TextStyle(color: Colors.grey[400], fontSize: 10),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📚 EXAM MODE ACTIVE',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        Text(
          'Active: $activeExams exams, $activeTakers students',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildAdvancedStats() {
    final peakUsers = _systemStats['peak_concurrent_users'] ?? 0;
    final estimatedMax = _systemStats['estimated_max_users'] ?? 0;
    final failureCount = _systemStats['failure_count'] ?? 0;
    final circuitBreaker = _systemStats['circuit_breaker_open'] ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.grey[600], height: 16),
        Text(
          'Advanced Stats:',
          style: TextStyle(color: Colors.grey[300], fontSize: 10),
        ),
        Text(
          'Peak Users Today: $peakUsers',
          style: TextStyle(color: Colors.grey[400], fontSize: 9),
        ),
        Text(
          'Est. Max Capacity: $estimatedMax users',
          style: TextStyle(color: Colors.grey[400], fontSize: 9),
        ),
        if (failureCount > 0)
          Text(
            'Failures: $failureCount',
            style: TextStyle(color: Colors.red, fontSize: 9),
          ),
        if (circuitBreaker)
          Text(
            '🚨 CIRCUIT BREAKER OPEN',
            style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
  
  Color _getStatusColor() {
    final status = _systemStats['system_status'] ?? 'UNKNOWN';
    switch (status) {
      case 'NORMAL': return Colors.green;
      case 'MODERATE_LOAD': return Colors.yellow;
      case 'HIGH_LOAD': return Colors.orange;
      case 'CRITICAL_OVERLOAD': return Colors.red;
      case 'CIRCUIT_BREAKER_OPEN': return Colors.purple;
      default: return Colors.grey;
    }
  }
  
  IconData _getStatusIcon() {
    final status = _systemStats['system_status'] ?? 'UNKNOWN';
    switch (status) {
      case 'NORMAL': return Icons.check_circle;
      case 'MODERATE_LOAD': return Icons.warning;
      case 'HIGH_LOAD': return Icons.error;
      case 'CRITICAL_OVERLOAD': return Icons.dangerous;
      case 'CIRCUIT_BREAKER_OPEN': return Icons.block;
      default: return Icons.help;
    }
  }
  
  Color _getRiskColor(String crashRisk) {
    if (crashRisk.contains('CRITICAL')) return Colors.red;
    if (crashRisk.contains('HIGH')) return Colors.orange;
    if (crashRisk.contains('MEDIUM')) return Colors.yellow;
    if (crashRisk.contains('LOW')) return Colors.green;
    return Colors.grey;
  }
  
  Color _getUsageColor(int usage) {
    if (usage >= 90) return Colors.red;
    if (usage >= 70) return Colors.orange;
    if (usage >= 50) return Colors.yellow;
    return Colors.green;
  }
}

/// Compact status bar for showing in app
class CompactSystemStatusBar extends StatefulWidget {
  @override
  _CompactSystemStatusBarState createState() => _CompactSystemStatusBarState();
}

class _CompactSystemStatusBarState extends State<CompactSystemStatusBar> {
  Timer? _updateTimer;
  String _statusMessage = '';
  Color _statusColor = Colors.green;
  
  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(Duration(seconds: 10), (_) => _updateStatus());
    _updateStatus();
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _updateStatus() {
    if (mounted) {
      setState(() {
        _statusMessage = FreePlanOptimizerService.getStatusMessage();
        _statusColor = _getMessageColor(_statusMessage);
      });
    }
  }
  
  Color _getMessageColor(String message) {
    if (message.contains('🚨')) return Colors.red;
    if (message.contains('⚠️')) return Colors.orange;
    if (message.contains('📊')) return Colors.blue;
    return Colors.green;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: double.infinity,
      color: _statusColor.withOpacity(0.1),
      child: Center(
        child: Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 10,
            color: _statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Emergency action panel for critical situations
class EmergencyActionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🚨 EMERGENCY ACTIONS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScalableConnectionService.emergencyThrottle();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Emergency throttle activated')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Throttle', style: TextStyle(fontSize: 10)),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScalableConnectionService.clearQueue();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Queue cleared')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text('Clear Queue', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
