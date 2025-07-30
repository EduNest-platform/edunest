package com.ranojit.edunest

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class ProctoringPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private var isProctoringActive = false
    private var appSwitchReceiver: BroadcastReceiver? = null
    private var lastAppSwitchTime = 0L
    private val violationThreshold = 1000L // 1 second threshold
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "android_proctoring")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "android_proctoring_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeProctoring(result)
            }
            "startProctoring" -> {
                startProctoring(result)
            }
            "stopProctoring" -> {
                stopProctoring(result)
            }
            "terminateTest" -> {
                terminateTest(result)
            }
            "getStatus" -> {
                getProctoringStatus(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun initializeProctoring(result: Result) {
        try {
            // Check if device supports proctoring features
            val isSupported = checkProctoringSupport()
            result.success(isSupported)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize proctoring", e.message)
        }
    }
    
    private fun startProctoring(result: Result) {
        try {
            if (isProctoringActive) {
                result.success(true)
                return
            }
            
            activity?.let { act ->
                // Enable fullscreen mode
                act.window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                
                // Prevent screenshots and screen recording
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
                    act.window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                }
                
                // Register app switch receiver
                registerAppSwitchReceiver()
                
                isProctoringActive = true
                result.success(true)
            } ?: run {
                result.error("NO_ACTIVITY", "No activity available", null)
            }
        } catch (e: Exception) {
            result.error("START_ERROR", "Failed to start proctoring", e.message)
        }
    }
    
    private fun stopProctoring(result: Result) {
        try {
            if (!isProctoringActive) {
                result.success(true)
                return
            }
            
            activity?.let { act ->
                // Remove fullscreen mode
                act.window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                
                // Remove secure flags
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
                    act.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
            }
            
            // Unregister receivers
            unregisterAppSwitchReceiver()
            
            isProctoringActive = false
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", "Failed to stop proctoring", e.message)
        }
    }
    
    private fun terminateTest(result: Result) {
        try {
            // Send termination event
            sendEvent("test_terminated", null)
            
            // Force close the app
            activity?.finishAndRemoveTask()
            
            result.success(true)
        } catch (e: Exception) {
            result.error("TERMINATE_ERROR", "Failed to terminate test", e.message)
        }
    }
    
    private fun getProctoringStatus(result: Result) {
        try {
            val status = mapOf(
                "supported" to checkProctoringSupport(),
                "advancedFeatures" to checkAdvancedFeatures(),
                "isActive" to isProctoringActive,
                "androidVersion" to Build.VERSION.SDK_INT,
                "deviceModel" to Build.MODEL
            )
            result.success(status)
        } catch (e: Exception) {
            result.error("STATUS_ERROR", "Failed to get status", e.message)
        }
    }
    
    private fun checkProctoringSupport(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP
    }
    
    private fun checkAdvancedFeatures(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
    }
    
    private fun registerAppSwitchReceiver() {
        appSwitchReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_CLOSE_SYSTEM_DIALOGS -> {
                        val reason = intent.getStringExtra("reason")
                        when (reason) {
                            "homekey" -> {
                                sendEvent("home_button_pressed", null)
                                handleViolation("Home button pressed")
                            }
                            "recentapps" -> {
                                sendEvent("recent_apps_pressed", null)
                                handleViolation("Recent apps button pressed")
                            }
                            "assist" -> {
                                sendEvent("assist_button_pressed", null)
                                handleViolation("Assist button pressed")
                            }
                        }
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        // User returned to the app
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - lastAppSwitchTime > violationThreshold) {
                            sendEvent("app_switch_detected", "User returned after app switch")
                            handleViolation("App switching detected")
                        }
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        
        // Use RECEIVER_NOT_EXPORTED for security
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(appSwitchReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(appSwitchReceiver, filter)
        }
    }
    
    private fun unregisterAppSwitchReceiver() {
        appSwitchReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
            appSwitchReceiver = null
        }
    }
    
    private fun setupKeyEventMonitoring() {
        // For now, we'll rely on broadcast receivers for key monitoring
        // This avoids potential issues with window callback delegation
        // Key events will be handled through the broadcast receiver
    }
    
    private fun handleViolation(violation: String) {
        lastAppSwitchTime = System.currentTimeMillis()
        
        // Send violation event
        sendEvent("violation_detected", violation)
        
        // Log violation for academic integrity
        logViolation(violation)
    }
    
    private fun logViolation(violation: String) {
        // TODO: Send violation to backend for logging
        println("PROCTORING_VIOLATION: $violation at ${Date()}")
    }
    
    private fun sendEvent(type: String, details: String?) {
        eventSink?.success(mapOf(
            "type" to type,
            "details" to details,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Clean up proctoring if active
        if (isProctoringActive) {
            try {
                unregisterAppSwitchReceiver()
                isProctoringActive = false
            } catch (e: Exception) {
                // Ignore cleanup errors
            }
        }
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnUserLeaveHintListener {
            if (isProctoringActive) {
                lastAppSwitchTime = System.currentTimeMillis()
                sendEvent("user_leave_hint", null)
            }
        }
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivity() {
        activity = null
    }
} 