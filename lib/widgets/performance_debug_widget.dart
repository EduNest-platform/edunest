import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/performance_optimization_service.dart';

class PerformanceDebugWidget extends StatefulWidget {
  final Widget child;
  
  const PerformanceDebugWidget({super.key, required this.child});

  @override
  State<PerformanceDebugWidget> createState() => _PerformanceDebugWidgetState();
}

class _PerformanceDebugWidgetState extends State<PerformanceDebugWidget> {
  bool _showDebugInfo = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_showDebugInfo)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Performance Debug',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () => setState(() => _showDebugInfo = false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...PerformanceOptimizationService.getPerformanceStats()
                      .entries
                      .map((entry) {
                    final isSlow = entry.value.inMilliseconds > 2000;
                    final isMedium = entry.value.inMilliseconds > 1000;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        '${entry.key}: ${entry.value.inMilliseconds}ms',
                        style: TextStyle(
                          color: isSlow ? Colors.red : isMedium ? Colors.orange : Colors.green,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 4),
                  Text(
                    'Slow operations (>2s):',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  ...PerformanceOptimizationService.getSlowOperations().map((op) => 
                    Text(op, style: const TextStyle(color: Colors.red, fontSize: 9))
                  ).toList(),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          PerformanceOptimizationService.clearStats();
                          setState(() {});
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 50,
          right: 10,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _showDebugInfo = !_showDebugInfo),
            backgroundColor: Colors.black54,
            child: Icon(
              _showDebugInfo ? Icons.visibility_off : Icons.speed,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}
