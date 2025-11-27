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
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ble_caps"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ===== CRITICAL: Prevenir sleep/throttling =====
        requestBatteryOptimizationExemption()
        acquireWakeLock()
    }

    override fun onDestroy() {
        releaseWakeLock()
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
                "Puntazo::BleWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryCaps" -> {
                    result.success(queryCaps())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryCaps(): Map<String, Any?> {
        val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = mgr.adapter
        if (adapter == null) {
            return mapOf(
                "isLeCodedPhySupported" to false,
                "isLe2MPhySupported" to false,
                "isLeExtendedAdvertisingSupported" to false,
                "isLePeriodicAdvertisingSupported" to false,
                "isOffloadedFilteringSupported" to false,
                "isOffloadedBatchingSupported" to false
            )
        }

        val is26 = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

        fun safeBool(check: () -> Boolean): Boolean? =
            if (is26) try { check() } catch (_: Throwable) { null } else null

        // Estas propiedades existen en API >= 26 (Android 8.0)
        return mapOf(
            "isLeCodedPhySupported" to safeBool { adapter.isLeCodedPhySupported },
            "isLe2MPhySupported" to safeBool { adapter.isLe2MPhySupported },
            "isLeExtendedAdvertisingSupported" to safeBool { adapter.isLeExtendedAdvertisingSupported },
            "isLePeriodicAdvertisingSupported" to safeBool { adapter.isLePeriodicAdvertisingSupported },
            "isOffloadedFilteringSupported" to safeBool { adapter.isOffloadedFilteringSupported },
            "isOffloadedBatchingSupported" to safeBool { adapter.isOffloadedScanBatchingSupported }
        )
    }
}
