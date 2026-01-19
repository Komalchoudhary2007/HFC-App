package com.example.hfc_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AppKeepaliveScheduler {
    private const val TAG = "AppKeepaliveScheduler"
    private const val REQUEST_CODE = 12346
    
    fun scheduleAlarm(context: Context, delayMs: Long = 5 * 60 * 1000L) {
        Log.d(TAG, "🔔 Scheduling restart via broadcast in ${delayMs / 1000} seconds...")
        
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // ⭐ CHECK PERMISSION: Verify exact alarm permission before scheduling (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "❌ CRITICAL: Cannot schedule exact alarm - SCHEDULE_EXACT_ALARM permission NOT granted!")
                Log.e(TAG, "   User must enable 'Alarms & reminders' in Settings → Apps → Your App")
                return // Exit early - don't schedule without permission
            }
        }
        
        // Create intent for broadcast receiver
        val intent = Intent(context, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
            putExtra("scheduled_by", "keepalive_service")
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Calculate trigger time using ELAPSED_REALTIME (more reliable!)
        val triggerTime = android.os.SystemClock.elapsedRealtime() + delayMs
        
        try {
            // Use setExactAndAllowWhileIdle - works even in Doze mode
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerTime,
                pendingIntent
            )
            Log.d(TAG, "✅ Keepalive restart scheduled via broadcast")
            Log.d(TAG, "   Delay: ${delayMs / 1000} seconds")
            Log.d(TAG, "   Will work in Doze mode")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException scheduling alarm: ${e.message}")
            Log.e(TAG, "   Likely cause: Missing SCHEDULE_EXACT_ALARM permission (Android 12+)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule keepalive restart: ${e.message}")
        }
    }
    
    fun cancelAlarm(context: Context) {
        Log.d(TAG, "Canceling alarm...")
        
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "✅ Alarm canceled successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error canceling alarm: ${e.message}", e)
        }
    }
}
