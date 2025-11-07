package com.example.Puntazo

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ble_caps"

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
