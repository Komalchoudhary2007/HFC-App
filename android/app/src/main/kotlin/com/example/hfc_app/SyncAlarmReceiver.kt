package com.example.hfc_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

class SyncAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val SYNC_INTERVAL = 5 * 60 * 1000L // 5 minutes
        
        fun scheduleSync(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, SyncAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Use setExactAndAllowWhileIdle for precise timing even in Doze mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + SYNC_INTERVAL,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + SYNC_INTERVAL,
                    pendingIntent
                )
            }
            
            println("⏰ [SyncAlarm] Next sync in ${SYNC_INTERVAL / 60000} minutes")
        }
        
        fun cancelSync(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, SyncAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            println("⏹️ [SyncAlarm] Sync alarms cancelled")
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        println("⏰ [SyncAlarm] Triggered - ensuring service is running")
        
        // Ensure foreground service is running
        val serviceIntent = Intent(context, ForegroundService::class.java)
        serviceIntent.action = ForegroundService.ACTION_START_SERVICE
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        // Schedule next alarm
        scheduleSync(context)
    }
}
