package com.example.Puntazo

import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.content.Intent
import android.content.Context
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.padelapp.NativeUsbSerial
import com.padelapp.UsbForegroundService

class MainActivity: FlutterActivity() {
    private val CHANNEL = "puntazo_system"
    private var wakeLock: PowerManager.WakeLock? = null
    private var usbSerial: NativeUsbSerial? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ===== CRITICAL: Prevenir sleep/throttling 24/7 =====
        requestBatteryOptimizationExemption()
        acquireWakeLock()
        
        // NOTE: Foreground service se inicia desde NativeUsbSerial cuando
        // hay un dispositivo USB conectado y permiso otorgado.
        // Esto es requerido por Android 14+ para foregroundServiceType="connectedDevice"
    }

    override fun onDestroy() {
        releaseWakeLock()
        usbSerial?.cleanup()
        // Note: Don't stop the foreground service on destroy - it should keep running
        super.onDestroy()
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            // Verificar si ya está exento
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    // Solicitar exención de optimizaciones de batería
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            // PARTIAL_WAKE_LOCK: Mantiene CPU activa pero permite que pantalla se apague
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE,
                "Puntazo::UsbWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(24 * 60 * 60 * 1000L)  // 24 hours max
            }
            android.util.Log.d("MainActivity", "🔒 WakeLock acquired for 24h")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                android.util.Log.d("MainActivity", "🔓 WakeLock released")
            }
        }
        wakeLock = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Inicializar USB Serial
        try {
            usbSerial = NativeUsbSerial(this, flutterEngine)
            usbSerial?.setup()
            android.util.Log.d("MainActivity", "✅ USB Serial initialized")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error inicializando USB Serial: ${e.message}", e)
        }

        // System channel for misc operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
