package com.padelapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground Service para mantener la conexión USB Serial activa 24/7
 * Previene que Android mate la app o suspenda la CPU
 */
class UsbForegroundService : Service() {
    
    companion object {
        private const val TAG = "UsbForegroundService"
        private const val CHANNEL_ID = "puntazo_usb_channel"
        private const val NOTIFICATION_ID = 1002
        
        fun start(context: Context) {
            val intent = Intent(context, UsbForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "✅ USB Service start requested")
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, UsbForegroundService::class.java)
            context.stopService(intent)
            Log.d(TAG, "🛑 USB Service stop requested")
        }
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔧 onCreate()")
        createNotificationChannel()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "▶️ onStartCommand()")
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // START_STICKY: Android reinicia el service si lo mata
        return START_STICKY
    }
    
    override fun onDestroy() {
        Log.d(TAG, "🛑 onDestroy()")
        releaseWakeLock()
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Puntazo USB Serial",
                NotificationManager.IMPORTANCE_LOW  // Sin sonido
            ).apply {
                description = "Mantiene la conexión USB Serial activa para recibir comandos"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "📢 Notification channel created")
        }
    }
    
    private fun createNotification(): Notification {
        // Intent para abrir la app al tocar la notificación
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Puntazo")
            .setContentText("Escuchando comandos USB Serial...")
            .setSmallIcon(android.R.drawable.ic_menu_rotate)  // USB-like icon
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Puntazo::UsbServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                // Acquire indefinitely - service manages lifecycle
                acquire(Long.MAX_VALUE)
            }
            Log.d(TAG, "🔒 WakeLock acquired (indefinite)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ WakeLock error: ${e.message}")
        }
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "🔓 WakeLock released")
            }
        }
        wakeLock = null
    }
}
