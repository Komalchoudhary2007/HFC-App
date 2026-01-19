package com.example.hfc_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout

/**
 * OverlayLauncher - Uses SYSTEM_ALERT_WINDOW permission to launch app when screen is ON
 * 
 * WHY THIS WORKS ON SCREEN-ON:
 * - Full-screen intent only works when screen is OFF (like alarm clocks)
 * - When screen is ON, we need SYSTEM_ALERT_WINDOW permission
 * - This permission allows us to draw over other apps
 * - From an overlay view, we CAN start activities (bypasses Android 10+ restriction)
 * 
 * FLOW:
 * 1. Check if we have overlay permission
 * 2. Add an invisible overlay view using WindowManager
 * 3. From that overlay context, launch MainActivity
 * 4. Remove the overlay immediately
 * 
 * This is how apps like Facebook Messenger chat heads work!
 */
object OverlayLauncher {
    private const val TAG = "OverlayLauncher"
    private var overlayView: View? = null
    
    /**
     * Check if the app has permission to draw overlays
     */
    fun hasOverlayPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true // Pre-Marshmallow doesn't need explicit permission
        }
    }
    
    /**
     * Request overlay permission from the user
     * This opens the system settings page for this app
     */
    fun requestOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivityForResult(intent, 1234)
            Log.d(TAG, "📱 Opened overlay permission settings")
        }
    }
    
    /**
     * Launch the app using overlay trick when screen is ON
     * This is the KEY method that bypasses Android 10+ restrictions!
     */
    fun launchAppViaOverlay(context: Context) {
        Log.d(TAG, "🚀 Attempting to launch app via overlay...")
        
        // Check overlay permission
        if (!hasOverlayPermission(context)) {
            Log.e(TAG, "❌ No overlay permission! Cannot launch app when screen is ON")
            Log.d(TAG, "   User needs to grant 'Display over other apps' permission")
            // Fall back to notification approach
            AppLauncher.launchApp(context)
            return
        }
        
        try {
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // Create an invisible overlay view
            val overlayView = FrameLayout(context)
            this.overlayView = overlayView
            
            // Configure layout params for the overlay
            val layoutParams = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams(
                    1, 1, // Minimal size (1x1 pixel - invisible)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                )
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams(
                    1, 1,
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                    PixelFormat.TRANSLUCENT
                )
            }
            
            layoutParams.gravity = Gravity.TOP or Gravity.START
            layoutParams.x = 0
            layoutParams.y = 0
            
            // Add overlay to window manager
            windowManager.addView(overlayView, layoutParams)
            Log.d(TAG, "   ✅ Overlay view added")
            
            // Acquire wake lock
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "hfc_app:overlay_wakelock"
            )
            wakeLock.acquire(5000)
            
            // Now launch the activity - THIS WORKS because we're in an overlay context!
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "overlay_launcher")
                putExtra("launch_time", System.currentTimeMillis())
            }
            
            context.startActivity(launchIntent)
            Log.d(TAG, "   ✅✅✅ MainActivity launched via overlay! ✅✅✅")
            
            // Clean up: Remove overlay after a short delay
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    windowManager.removeView(overlayView)
                    this.overlayView = null
                    Log.d(TAG, "   ✅ Overlay view removed")
                    
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "   ⚠️ Error cleaning up: ${e.message}")
                }
            }, 1000)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch via overlay: ${e.message}", e)
            // Fall back to regular launch attempt
            AppLauncher.launchApp(context)
        }
    }
    
    /**
     * Remove overlay if it's still showing
     */
    fun removeOverlay(context: Context) {
        try {
            overlayView?.let { view ->
                val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager.removeView(view)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
    }
}
