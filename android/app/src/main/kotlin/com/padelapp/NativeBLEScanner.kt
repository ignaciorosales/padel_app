package com.padelapp

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class NativeBLEScanner(private val flutterEngine: FlutterEngine) {
    private val METHOD_CHANNEL = "com.padelapp/ble"
    private val EVENT_CHANNEL = "com.padelapp/ble_events"
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val handler = Handler(Looper.getMainLooper())
    
    // Debounce: (devId, cmd) -> (lastSeq, lastTime)
    private val lastEvents = mutableMapOf<String, Pair<Int, Long>>()
    
    fun setup() {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    startScan()
                    result.success(null)
                }
                "stopScan" -> {
                    stopScan()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
    
    private fun sendDebug(msg: String) {
        handler.post {
            eventSink?.success(mapOf("type" to "debug", "data" to msg))
        }
    }
    
    private fun sendCommand(cmd: String) {
        handler.post {
            eventSink?.success(mapOf("type" to "command", "data" to cmd))
        }
    }
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            processScanResult(result)
        }
        
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            for (result in results) {
                processScanResult(result)
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            sendDebug("Scan failed: $errorCode")
        }
    }
    
    private fun startScan() {
        try {
            if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                sendDebug("⚠️ Bluetooth no disponible")
                return
            }
            
            val scanner = bluetoothAdapter.bluetoothLeScanner
            if (scanner == null) {
                sendDebug("⚠️ BLE scanner no disponible")
                return
            }
            
            // Scan agresivo LOW_LATENCY (como Python)
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            
            scanner.startScan(null, settings, scanCallback)
            sendDebug("✅ Scan activo")
            
        } catch (e: Exception) {
            sendDebug("Error: ${e.message}")
        }
    }
    
    private fun stopScan() {
        try {
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            sendDebug("Scan detenido")
        } catch (e: Exception) {
            // ignore
        }
    }
    
    private fun processScanResult(result: ScanResult) {
        try {
            val scanRecord = result.scanRecord ?: return
            val data = scanRecord.bytes ?: return
            
            // Buscar 'PS' en cualquier posición (como Python)
            var psIdx = -1
            for (i in 0 until data.size - 9) {
                if (data[i] == 0x50.toByte() && data[i + 1] == 0x53.toByte()) {
                    psIdx = i
                    break
                }
            }
            
            if (psIdx == -1) return
            
            // Parse: ['P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi]
            val devLo = data[psIdx + 3].toInt() and 0xFF
            val devHi = data[psIdx + 4].toInt() and 0xFF
            val devId = devLo or (devHi shl 8)
            val cmdCh = data[psIdx + 6].toInt().toChar()
            val seq = data[psIdx + 7].toInt() and 0xFF
            
            // DEBOUNCE (como Python: 300ms)
            val nowMs = System.currentTimeMillis()
            val key = "${devId}_$cmdCh"
            val lastEvent = lastEvents[key]
            
            // 1) Misma seq -> ignorar
            if (lastEvent != null && lastEvent.first == seq) {
                return
            }
            
            // 2) Seq distinta pero <300ms -> debounce
            if (lastEvent != null && (nowMs - lastEvent.second) < 300) {
                lastEvents[key] = Pair(seq, nowMs)
                return
            }
            
            // Aceptar evento
            lastEvents[key] = Pair(seq, nowMs)
            
            // Mapeo de dispositivos
            val isTeamA = devId == 0x0201 || devId == 0x0203
            val isTeamB = devId == 0x0202 || devId == 0x0204
            
            // Emitir comandos
            when (cmdCh) {
                'p' -> {
                    if (isTeamA) {
                        sendCommand("P_A")
                        sendDebug("Punto A")
                    } else if (isTeamB) {
                        sendCommand("P_B")
                        sendDebug("Punto B")
                    }
                }
                'u' -> {
                    if (isTeamA) {
                        sendCommand("UNDO_A")
                        sendDebug("Undo A")
                    } else if (isTeamB) {
                        sendCommand("UNDO_B")
                        sendDebug("Undo B")
                    }
                }
                'g' -> {
                    sendCommand("RESET_GAME")
                    sendDebug("Reset")
                }
            }
            
        } catch (e: Exception) {
            // ignore parsing errors
        }
    }
}
