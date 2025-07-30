package com.ranojit.edunest

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the proctoring plugin
        flutterEngine.plugins.add(ProctoringPlugin())
    }
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // App Center SDK removed. Add new analytics or distribution SDK here if needed.
    }
} 