package com.padelapp

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class NativeBLEScanner(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) {
    private val TAG = "NativeBLEScanner"
    private val METHOD_CHANNEL = "com.padelapp/ble"
    private val EVENT_CHANNEL = "com.padelapp/ble_events"
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val handler = Handler(Looper.getMainLooper())
    
    // Debounce: (devId, cmd) -> (lastSeq, lastTime)
    private val lastEvents = mutableMapOf<String, Pair<Int, Long>>()
    
    // Contador de scan results para debug
    private var scanResultCount = 0
    private var psPacketCount = 0
    private var lastScanResultTime = 0L
    private var isScanning = false
    
    // ===== WATCHDOG: Reiniciar scan cada 5 minutos para evitar throttling =====
    private val SCAN_RESTART_INTERVAL_MS = 5 * 60 * 1000L  // 5 minutos
    private val WATCHDOG_CHECK_INTERVAL_MS = 30 * 1000L     // 30 segundos
    private val SCAN_DEAD_THRESHOLD_MS = 60 * 1000L         // 1 minuto sin resultados = muerto
    
    private val scanRestartRunnable = object : Runnable {
        override fun run() {
            if (isScanning) {
                Log.d(TAG, "🔄 WATCHDOG: Reiniciando scan preventivo (anti-throttling)")
                sendDebug("🔄 Reinicio preventivo del scan")
                restartScan()
            }
            handler.postDelayed(this, SCAN_RESTART_INTERVAL_MS)
        }
    }
    
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (isScanning) {
                val now = System.currentTimeMillis()
                val timeSinceLastResult = now - lastScanResultTime
                
                // Reportar stats
                sendDebug("📊 Stats: $scanResultCount scans, $psPacketCount PS")
                
                // Si no hay resultados en 1 minuto, el scan está muerto
                if (lastScanResultTime > 0 && timeSinceLastResult > SCAN_DEAD_THRESHOLD_MS) {
                    Log.w(TAG, "⚠️ WATCHDOG: Scan muerto! Sin resultados en ${timeSinceLastResult/1000}s")
                    sendDebug("⚠️ Scan muerto! Reiniciando...")
                    restartScan()
                }
            }
            handler.postDelayed(this, WATCHDOG_CHECK_INTERVAL_MS)
        }
    }
    
    fun setup() {
        Log.d(TAG, "🔧 setup() called")
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "📞 Method call: ${call.method}")
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
                Log.d(TAG, "📡 EventChannel onListen - eventSink ${if (events != null) "SET" else "NULL"}")
                eventSink = events
                sendDebug("📲 EventChannel conectado (listo para logs)")
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "📡 EventChannel onCancel")
                eventSink = null
            }
        })
        
        Log.d(TAG, "🔧 setup() complete")
    }
    
    // Verificar permiso BLUETOOTH_SCAN en Android 12+
    private fun hasScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val result = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN)
            val granted = result == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "🔑 BLUETOOTH_SCAN permission: $granted")
            granted
        } else {
            // Pre-Android 12: verificar ACCESS_FINE_LOCATION
            val result = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
            val granted = result == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "🔑 ACCESS_FINE_LOCATION permission: $granted")
            granted
        }
    }
    
    private fun sendDebug(msg: String) {
        Log.d(TAG, "📤 DEBUG: $msg")
        handler.post {
            eventSink?.success(mapOf("type" to "debug", "data" to msg))
        }
    }
    
    private fun sendCommand(cmd: String) {
        Log.d(TAG, "📤 COMMAND: $cmd")
        handler.post {
            eventSink?.success(mapOf("type" to "command", "data" to cmd))
        }
    }
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            processScanResult(result)
        }
        
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            Log.d(TAG, "📦 Batch results: ${results.size}")
            for (result in results) {
                processScanResult(result)
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            val errorMsg = when (errorCode) {
                SCAN_FAILED_ALREADY_STARTED -> "ALREADY_STARTED"
                SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "APP_REGISTRATION_FAILED"
                SCAN_FAILED_INTERNAL_ERROR -> "INTERNAL_ERROR"
                SCAN_FAILED_FEATURE_UNSUPPORTED -> "FEATURE_UNSUPPORTED"
                else -> "UNKNOWN($errorCode)"
            }
            Log.e(TAG, "❌ Scan failed: $errorMsg")
            sendDebug("❌ Scan failed: $errorMsg")
        }
    }
    
    private fun startScan() {
        Log.d(TAG, "🚀 startScan() called")
        sendDebug("▶️ startScan() llamado")
        scanResultCount = 0
        psPacketCount = 0
        
        try {
            // 1) Verificar permisos
            if (!hasScanPermission()) {
                val msg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    "⛔ Falta permiso BLUETOOTH_SCAN (Android 12+)"
                } else {
                    "⛔ Falta permiso ACCESS_FINE_LOCATION (Android <12)"
                }
                Log.e(TAG, msg)
                sendDebug(msg)
                return
            }
            
            // 2) Verificar BluetoothAdapter
            if (bluetoothAdapter == null) {
                Log.e(TAG, "❌ BluetoothAdapter is NULL")
                sendDebug("⛔ BluetoothAdapter == null")
                return
            }
            
            if (!bluetoothAdapter.isEnabled) {
                Log.e(TAG, "❌ Bluetooth is DISABLED")
                sendDebug("⛔ Bluetooth está APAGADO")
                return
            }
            
            Log.d(TAG, "✅ Bluetooth enabled, adapter OK")
            sendDebug("✅ Bluetooth ON, adapter OK")
            
            // 3) Verificar BLE Scanner
            val scanner = bluetoothAdapter.bluetoothLeScanner
            if (scanner == null) {
                Log.e(TAG, "❌ BLE Scanner is NULL")
                sendDebug("⛔ BLE Scanner == null")
                return
            }
            
            Log.d(TAG, "✅ BLE Scanner OK")
            
            // 4) Configurar e iniciar scan
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            
            scanner.startScan(null, settings, scanCallback)
            Log.d(TAG, "✅ startScan() initiated")
            sendDebug("✅ Scan BLE activo (LOW_LATENCY)")
            
            isScanning = true
            lastScanResultTime = System.currentTimeMillis()
            
            // Iniciar watchdog y reinicio preventivo
            handler.postDelayed(watchdogRunnable, WATCHDOG_CHECK_INTERVAL_MS)
            handler.postDelayed(scanRestartRunnable, SCAN_RESTART_INTERVAL_MS)
            
            // Iniciar Foreground Service para mantener app viva
            BleForegroundService.start(context)
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException: ${e.message}")
            sendDebug("⛔ SecurityException: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception: ${e.message}")
            sendDebug("❌ Error: ${e.javaClass.simpleName}: ${e.message}")
        }
    }
    
    private fun stopScan() {
        Log.d(TAG, "🛑 stopScan() called")
        try {
            isScanning = false
            handler.removeCallbacks(watchdogRunnable)
            handler.removeCallbacks(scanRestartRunnable)
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            BleForegroundService.stop(context)
            sendDebug("Scan detenido (results=$scanResultCount, PS=$psPacketCount)")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping scan: ${e.message}")
        }
    }
    
    private fun restartScan() {
        Log.d(TAG, "🔄 restartScan() called")
        try {
            // Detener sin parar watchdog
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            
            // Esperar un momento
            handler.postDelayed({
                try {
                    val scanner = bluetoothAdapter?.bluetoothLeScanner
                    if (scanner != null && isScanning) {
                        val settings = ScanSettings.Builder()
                            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                            .build()
                        
                        scanner.startScan(null, settings, scanCallback)
                        lastScanResultTime = System.currentTimeMillis()
                        Log.d(TAG, "✅ Scan reiniciado OK")
                        sendDebug("✅ Scan reiniciado")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error reiniciando scan: ${e.message}")
                    sendDebug("❌ Error reiniciando: ${e.message}")
                }
            }, 500)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error en restartScan: ${e.message}")
        }
    }
    
    // CRC16-CCITT (poly=0x1021, init=0xFFFF)
    private fun crc16Ccitt(data: ByteArray, offset: Int, len: Int): Int {
        var crc = 0xFFFF
        for (i in offset until offset + len) {
            crc = crc xor ((data[i].toInt() and 0xFF) shl 8)
            for (b in 0 until 8) {
                crc = if ((crc and 0x8000) != 0) {
                    (crc shl 1) xor 0x1021
                } else {
                    crc shl 1
                }
                crc = crc and 0xFFFF
            }
        }
        return crc
    }
    
    private fun bytesToHex(bytes: ByteArray, maxLen: Int = 30): String {
        val len = minOf(bytes.size, maxLen)
        return bytes.take(len).joinToString(" ") { "%02X".format(it) } + 
               if (bytes.size > maxLen) "..." else ""
    }
    
    private fun processScanResult(result: ScanResult) {
        scanResultCount++
        lastScanResultTime = System.currentTimeMillis()
        
        try {
            val scanRecord = result.scanRecord
            if (scanRecord == null) {
                return
            }
            
            val data = scanRecord.bytes
            if (data == null || data.isEmpty()) {
                return
            }
            
            // Log cada 100 scan results para no saturar
            if (scanResultCount % 100 == 1) {
                Log.d(TAG, "📊 Scan results: $scanResultCount, PS packets: $psPacketCount")
            }
            
            // Buscar 'PS' (0x50 0x53) en cualquier posición
            var psIdx = -1
            for (i in 0 until data.size - 9) {
                if (data[i] == 0x50.toByte() && data[i + 1] == 0x53.toByte()) {
                    psIdx = i
                    break
                }
            }
            
            if (psIdx == -1) {
                return  // No es nuestro paquete
            }
            
            // ¡Encontramos 'PS'!
            psPacketCount++
            Log.d(TAG, "🎯 PS found at idx=$psIdx, raw=${bytesToHex(data)}")
            
            // Verificar que hay suficientes bytes
            if (psIdx + 10 > data.size) {
                Log.w(TAG, "⚠️ Packet too short: need ${psIdx + 10}, have ${data.size}")
                sendDebug("⚠️ Paquete muy corto")
                return
            }
            
            // Parse: ['P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi]
            val ver = data[psIdx + 2].toInt() and 0xFF
            val devLo = data[psIdx + 3].toInt() and 0xFF
            val devHi = data[psIdx + 4].toInt() and 0xFF
            val devId = devLo or (devHi shl 8)
            val marker = data[psIdx + 5].toInt().toChar()
            val cmdCh = data[psIdx + 6].toInt().toChar()
            val seq = data[psIdx + 7].toInt() and 0xFF
            val crcLo = data[psIdx + 8].toInt() and 0xFF
            val crcHi = data[psIdx + 9].toInt() and 0xFF
            val crcRx = crcLo or (crcHi shl 8)
            
            Log.d(TAG, "📦 Parsed: ver=$ver dev=0x${devId.toString(16)} marker='$marker' cmd='$cmdCh' seq=$seq crc=0x${crcRx.toString(16)}")
            
            // Validar marcador 'C'
            if (marker != 'C') {
                Log.w(TAG, "⚠️ Invalid marker: '$marker' (expected 'C')")
                sendDebug("⚠️ Marker inválido: '$marker'")
                return
            }
            
            // Validar CRC
            val crcCalc = crc16Ccitt(data, psIdx, 8)
            if (crcCalc != crcRx) {
                Log.w(TAG, "⚠️ CRC mismatch: rx=0x${crcRx.toString(16)} calc=0x${crcCalc.toString(16)}")
                sendDebug("⚠️ CRC fail: rx=0x${crcRx.toString(16)} calc=0x${crcCalc.toString(16)}")
                return
            }
            
            Log.d(TAG, "✅ CRC OK")
            sendDebug("📦 dev=0x${devId.toString(16)} cmd='$cmdCh' seq=$seq ✓CRC")
            
            // DEBOUNCE
            val nowMs = System.currentTimeMillis()
            val key = "${devId}_$cmdCh"
            val lastEvent = lastEvents[key]
            
            if (lastEvent != null) {
                val lastSeq = lastEvent.first
                val lastTime = lastEvent.second
                val dt = nowMs - lastTime
                
                if (seq == lastSeq) {
                    Log.d(TAG, "🔄 Duplicate seq=$seq, ignoring")
                    return
                }
                
                if (dt < 300) {
                    Log.d(TAG, "🔄 Burst packet (dt=${dt}ms < 300ms), ignoring")
                    lastEvents[key] = Pair(seq, lastTime)
                    return
                }
            }
            
            // ¡Aceptar evento!
            lastEvents[key] = Pair(seq, nowMs)
            Log.d(TAG, "✅ ACCEPTED: dev=0x${devId.toString(16)} cmd='$cmdCh' seq=$seq")
            
            // Mapeo de dispositivos
            val isTeamA = devId == 0x0201 || devId == 0x0203
            val isTeamB = devId == 0x0202 || devId == 0x0204
            
            // Emitir comandos
            when (cmdCh) {
                'p' -> {
                    if (isTeamA) {
                        sendCommand("P_A")
                        sendDebug("✅ PUNTO A (dev=0x${devId.toString(16)})")
                    } else if (isTeamB) {
                        sendCommand("P_B")
                        sendDebug("✅ PUNTO B (dev=0x${devId.toString(16)})")
                    } else {
                        Log.w(TAG, "⚠️ Unknown device for 'p': 0x${devId.toString(16)}")
                        sendDebug("⚠️ Device desconocido: 0x${devId.toString(16)}")
                    }
                }
                'u' -> {
                    if (isTeamA) {
                        sendCommand("UNDO_A")
                        sendDebug("✅ UNDO A")
                    } else if (isTeamB) {
                        sendCommand("UNDO_B")
                        sendDebug("✅ UNDO B")
                    }
                }
                'g' -> {
                    sendCommand("RESET_GAME")
                    sendDebug("✅ RESET")
                }
                'n' -> {
                    // 'n' = no command, silent
                    Log.d(TAG, "📭 No command (cmd='n')")
                }
                else -> {
                    Log.w(TAG, "⚠️ Unknown command: '$cmdCh'")
                    sendDebug("⚠️ Comando desconocido: '$cmdCh'")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Parse error: ${e.message}", e)
            sendDebug("❌ Error: ${e.message}")
        }
    }
}
