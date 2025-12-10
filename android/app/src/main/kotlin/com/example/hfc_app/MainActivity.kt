package com.example.hfc_app

import android.content.Intent
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hfc.app/background"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBackgroundExecution" -> {
                    enableBackgroundExecution()
                    result.success(true)
                }
                "disableBackgroundExecution" -> {
                    disableBackgroundExecution()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun enableBackgroundExecution() {
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Start foreground service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun disableBackgroundExecution() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Stop foreground service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        stopService(serviceIntent)
    }
    
    override fun onDestroy() {
        disableBackgroundExecution()
        super.onDestroy()
    }
}
