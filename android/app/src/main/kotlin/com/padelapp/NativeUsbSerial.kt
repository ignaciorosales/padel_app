package com.padelapp

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

class NativeUsbSerial(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) {
    private val TAG = "NativeUsbSerial"
    private val METHOD_CHANNEL = "com.padelapp/usb_serial"
    private val EVENT_CHANNEL = "com.padelapp/usb_serial_events"
    private val ACTION_USB_PERMISSION = "com.padelapp.USB_PERMISSION"
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    
    private var usbManager: UsbManager? = null
    private var usbDevice: UsbDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    
    // CDC-ACM simple implementation
    private var readEndpoint: android.hardware.usb.UsbEndpoint? = null
    private var writeEndpoint: android.hardware.usb.UsbEndpoint? = null
    
    private var isConnected = false
    private var isReading = false
    private var bytesReceived = 0
    private var bytesSent = 0
    
    // Chip type for proper initialization
    private enum class ChipType { CDC_ACM, CH340, CP210X, UNKNOWN }
    private var chipType = ChipType.UNKNOWN
    
    // USB Permission receiver
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                sendDebug("✅ Permiso USB concedido")
                                openDevice(it)
                            }
                        } else {
                            sendDebug("❌ Permiso USB denegado")
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    sendDebug("📱 Dispositivo USB conectado")
                    refreshDevices()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    sendDebug("📱 Dispositivo USB desconectado")
                    disconnect()
                }
            }
        }
    }
    
    fun setup() {
        Log.d(TAG, "🔧 setup() called")
        
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        
        // Register USB receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }
        
        // Setup Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "📞 Method call: ${call.method}")
            when (call.method) {
                "getDevices" -> {
                    result.success(getDeviceList())
                }
                "connect" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        connectToDevice(deviceId)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "deviceId required", null)
                    }
                }
                "disconnect" -> {
                    disconnect()
                    result.success(null)
                }
                "send" -> {
                    val data = call.argument<String>("data")
                    if (data != null) {
                        writeUsb(data)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "data required", null)
                    }
                }
                "getStatus" -> {
                    result.success(getStatus())
                }
                else -> result.notImplemented()
            }
        }
        
        // Setup Event Channel
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "📡 EventChannel onListen")
                eventSink = events
                sendDebug("📲 USB Serial conectado")
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "📡 EventChannel onCancel")
                eventSink = null
            }
        })
        
        Log.d(TAG, "🔧 setup() complete")
    }
    
    fun cleanup() {
        try {
            context.unregisterReceiver(usbReceiver)
            disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "cleanup error: ${e.message}")
        }
    }
    
    private fun sendDebug(msg: String) {
        Log.d(TAG, "📤 DEBUG: $msg")
        handler.post {
            eventSink?.success(mapOf("type" to "debug", "data" to msg))
        }
    }
    
    private fun sendDataEvent(msg: String) {
        Log.d(TAG, "📤 DATA: $msg")
        handler.post {
            eventSink?.success(mapOf("type" to "data", "data" to msg))
        }
    }
    
    private fun sendStatus(connected: Boolean) {
        handler.post {
            eventSink?.success(mapOf("type" to "status", "connected" to connected))
        }
    }
    
    private fun getDeviceList(): List<Map<String, Any>> {
        val devices = mutableListOf<Map<String, Any>>()
        usbManager?.deviceList?.values?.forEach { device ->
            devices.add(mapOf(
                "deviceId" to device.deviceId,
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "deviceName" to (device.deviceName ?: "Unknown"),
                "manufacturerName" to (device.manufacturerName ?: "Unknown"),
                "productName" to (device.productName ?: "Unknown")
            ))
        }
        sendDebug("📋 ${devices.size} dispositivos USB encontrados")
        return devices
    }
    
    private fun refreshDevices() {
        val devices = getDeviceList()
        handler.post {
            eventSink?.success(mapOf("type" to "devices", "devices" to devices))
        }
    }
    
    private fun getStatus(): Map<String, Any> {
        return mapOf(
            "connected" to isConnected,
            "bytesReceived" to bytesReceived,
            "bytesSent" to bytesSent,
            "deviceName" to (usbDevice?.productName ?: "None")
        )
    }
    
    private fun connectToDevice(deviceId: Int) {
        val device = usbManager?.deviceList?.values?.find { it.deviceId == deviceId }
        if (device == null) {
            sendDebug("❌ Dispositivo no encontrado: $deviceId")
            return
        }
        
        sendDebug("🔌 Conectando a ${device.productName ?: device.deviceName}...")
        
        if (usbManager?.hasPermission(device) == true) {
            openDevice(device)
        } else {
            // Request permission
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val permissionIntent = PendingIntent.getBroadcast(
                context, 0, Intent(ACTION_USB_PERMISSION), flags
            )
            usbManager?.requestPermission(device, permissionIntent)
            sendDebug("🔑 Solicitando permiso USB...")
        }
    }
    
    private fun openDevice(device: UsbDevice) {
        try {
            usbDevice = device
            usbConnection = usbManager?.openDevice(device)
            
            if (usbConnection == null) {
                sendDebug("❌ No se pudo abrir el dispositivo")
                return
            }
            
            // Detect chip type by VID/PID
            chipType = detectChipType(device.vendorId, device.productId)
            sendDebug("🔍 Chip: $chipType (VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)})")
            
            // Find interface - prefer CDC Data (class 10) for proper CDC-ACM
            var dataInterface: android.hardware.usb.UsbInterface? = null
            var controlInterface: android.hardware.usb.UsbInterface? = null
            
            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                Log.d(TAG, "Interface $i: class=${intf.interfaceClass}, endpoints=${intf.endpointCount}")
                sendDebug("📋 Interface $i: class=${intf.interfaceClass}, ${intf.endpointCount} endpoints")
                
                when (intf.interfaceClass) {
                    10 -> { // CDC Data class - this is what we want for data transfer
                        dataInterface = intf
                        sendDebug("✅ Found CDC Data interface: $i")
                    }
                    2 -> { // CDC Control class
                        controlInterface = intf
                    }
                    255 -> { // Vendor specific - fallback
                        if (dataInterface == null) dataInterface = intf
                    }
                }
            }
            
            // Fallback: find any interface with bulk endpoints
            if (dataInterface == null) {
                for (i in 0 until device.interfaceCount) {
                    val intf = device.getInterface(i)
                    for (e in 0 until intf.endpointCount) {
                        val ep = intf.getEndpoint(e)
                        if (ep.type == android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK) {
                            dataInterface = intf
                            sendDebug("📋 Using fallback interface: $i")
                            break
                        }
                    }
                    if (dataInterface != null) break
                }
            }
            
            if (dataInterface == null) {
                sendDebug("❌ No se encontró interfaz con endpoints bulk")
                disconnect()
                return
            }
            
            // Claim interface
            if (!usbConnection!!.claimInterface(dataInterface, true)) {
                sendDebug("❌ No se pudo reclamar la interfaz")
                disconnect()
                return
            }
            
            // Find bulk endpoints
            for (i in 0 until dataInterface.endpointCount) {
                val ep = dataInterface.getEndpoint(i)
                if (ep.type == android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == android.hardware.usb.UsbConstants.USB_DIR_IN) {
                        readEndpoint = ep
                        sendDebug("📥 Read endpoint: 0x${ep.address.toString(16)}")
                    } else {
                        writeEndpoint = ep
                        sendDebug("📤 Write endpoint: 0x${ep.address.toString(16)}")
                    }
                }
            }
            
            if (readEndpoint == null) {
                sendDebug("⚠️ No hay endpoint de lectura")
            }
            if (writeEndpoint == null) {
                sendDebug("⚠️ No hay endpoint de escritura")
            }
            
            // Initialize chip - usar método genérico CDC
            sendDebug("🔧 Configurando 115200bps 8N1...")
            setLineCoding(115200, 8, 0, 0)
            
            // Si es CH340/CP210X, intentar init adicional (no crítico)
            when (chipType) {
                ChipType.CH340 -> tryInitCH340()
                ChipType.CP210X -> tryInitCP210X()
                else -> { }
            }
            
            isConnected = true
            bytesReceived = 0
            bytesSent = 0
            
            sendDebug("✅ ¡Conectado! Esperando datos...")
            sendStatus(true)
            
            // Start reading
            if (readEndpoint != null) {
                startReading()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error opening device: ${e.message}", e)
            sendDebug("❌ Error: ${e.message}")
            disconnect()
        }
    }
    
    private fun detectChipType(vendorId: Int, productId: Int): ChipType {
        return when {
            // ESP32-C3/S2/S3 con USB nativo (Espressif)
            vendorId == 0x303A -> ChipType.CDC_ACM
            // CH340/CH341
            vendorId == 0x1A86 && (productId == 0x7523 || productId == 0x5523 || productId == 0x7522) -> ChipType.CH340
            // CP210X (Silicon Labs)
            vendorId == 0x10C4 && (productId == 0xEA60 || productId == 0xEA70 || productId == 0xEA80) -> ChipType.CP210X
            // FTDI
            vendorId == 0x0403 -> ChipType.CDC_ACM
            else -> ChipType.CDC_ACM // Asumir CDC para desconocidos
        }
    }
    
    private fun initCH340(baudRate: Int) {
        sendDebug("🔧 Inicializando CH340 @ $baudRate baud...")
        val conn = usbConnection ?: return
        
        try {
            // CH340 initialization sequence
            conn.controlTransfer(0x40, 0xA1, 0, 0, null, 0, 1000)
            conn.controlTransfer(0x40, 0x9A, 0x2518, 0x0050, null, 0, 1000)
            conn.controlTransfer(0x40, 0xA1, 0x501F, 0xD90A, null, 0, 1000)
            
            // Set baud rate - CH340 uses divisors
            val divisor = when (baudRate) {
                9600 -> 0xB2
                19200 -> 0xD9
                38400 -> 0x6D
                57600 -> 0x48
                115200 -> 0x24
                else -> 0xB2 // default 9600
            }
            
            conn.controlTransfer(0x40, 0x9A, 0x1312, 0x00B2 or 0x80, null, 0, 1000)
            conn.controlTransfer(0x40, 0x9A, 0x0F2C, divisor, null, 0, 1000)
            
            // Enable TX/RX
            conn.controlTransfer(0x40, 0xA4, 0x00FF, 0, null, 0, 1000)
            
            sendDebug("✅ CH340 inicializado")
        } catch (e: Exception) {
            sendDebug("⚠️ CH340 init: ${e.message}")
        }
    }
    
    // Versión no-crítica para CH340 (opcional, no bloquea si falla)
    private fun tryInitCH340() {
        try {
            val conn = usbConnection ?: return
            // Solo DTR/RTS
            conn.controlTransfer(0x40, 0xA4, 0x00FF, 0, null, 0, 500)
        } catch (e: Exception) {
            // Ignorar - no es crítico
        }
    }
    
    // Versión no-crítica para CP210X (opcional)
    private fun tryInitCP210X() {
        try {
            val conn = usbConnection ?: return
            // Solo habilitar interfaz
            conn.controlTransfer(0x41, 0x00, 0x0001, 0, null, 0, 500)
        } catch (e: Exception) {
            // Ignorar - no es crítico
        }
    }
    
    private fun initCP210X(baudRate: Int) {
        sendDebug("🔧 Inicializando CP210X @ $baudRate baud...")
        val conn = usbConnection ?: return
        
        try {
            // Enable interface
            conn.controlTransfer(0x41, 0x00, 0x0001, 0, null, 0, 1000)
            
            // Set baud rate
            val baudBytes = byteArrayOf(
                (baudRate and 0xFF).toByte(),
                ((baudRate shr 8) and 0xFF).toByte(),
                ((baudRate shr 16) and 0xFF).toByte(),
                ((baudRate shr 24) and 0xFF).toByte()
            )
            conn.controlTransfer(0x41, 0x1E, 0, 0, baudBytes, 4, 1000)
            
            // Set 8N1 (data bits = 8, parity = none, stop bits = 1)
            conn.controlTransfer(0x41, 0x03, 0x0800, 0, null, 0, 1000)
            
            // Set DTR/RTS
            conn.controlTransfer(0x41, 0x07, 0x0303, 0, null, 0, 1000)
            
            sendDebug("✅ CP210X inicializado")
        } catch (e: Exception) {
            sendDebug("⚠️ CP210X init: ${e.message}")
        }
    }
    
    private fun setLineCoding(baudRate: Int, dataBits: Int, stopBits: Int, parity: Int) {
        try {
            // CDC SET_LINE_CODING (0x20)
            val lineCode = byteArrayOf(
                (baudRate and 0xFF).toByte(),
                ((baudRate shr 8) and 0xFF).toByte(),
                ((baudRate shr 16) and 0xFF).toByte(),
                ((baudRate shr 24) and 0xFF).toByte(),
                stopBits.toByte(),
                parity.toByte(),
                dataBits.toByte()
            )
            
            usbConnection?.controlTransfer(
                0x21, // Host to device, class, interface
                0x20, // SET_LINE_CODING
                0,
                0,
                lineCode,
                lineCode.size,
                100
            )
            
            // SET_CONTROL_LINE_STATE (DTR + RTS)
            usbConnection?.controlTransfer(
                0x21,
                0x22, // SET_CONTROL_LINE_STATE
                0x03, // DTR + RTS
                0,
                null,
                0,
                100
            )
        } catch (e: Exception) {
            Log.w(TAG, "setLineCoding warning: ${e.message}")
        }
    }
    
    // Buffer para acumular datos parciales (comandos pueden llegar fragmentados)
    private val lineBuffer = StringBuilder()
    
    // Comandos válidos que la app reconoce
    private val VALID_COMMANDS = setOf("P_A", "P_B", "UNDO_A", "UNDO_B", "RESET", "PONG")
    
    private fun startReading() {
        if (isReading) return
        isReading = true
        lineBuffer.clear()
        
        executor.execute {
            val buffer = ByteArray(1024)
            
            while (isReading && isConnected && usbConnection != null && readEndpoint != null) {
                try {
                    val len = usbConnection?.bulkTransfer(readEndpoint, buffer, buffer.size, 100) ?: -1
                    
                    if (len > 0) {
                        bytesReceived += len
                        val data = String(buffer, 0, len, Charsets.UTF_8)
                        val hex = buffer.take(len).joinToString(" ") { "%02X".format(it) }
                        
                        Log.d(TAG, "📥 Received $len bytes: $hex")
                        
                        // Send raw data event for debugging
                        handler.post {
                            eventSink?.success(mapOf(
                                "type" to "rx",
                                "data" to data,
                                "hex" to hex,
                                "length" to len
                            ))
                        }
                        
                        // Parse commands from incoming data
                        parseIncomingData(data)
                    }
                } catch (e: Exception) {
                    if (isReading) {
                        Log.e(TAG, "Read error: ${e.message}")
                    }
                }
            }
            
            Log.d(TAG, "📖 Read loop ended")
        }
    }
    
    // Parse incoming data looking for commands (line-based)
    private fun parseIncomingData(data: String) {
        lineBuffer.append(data)
        
        // Process complete lines
        var newlineIdx = lineBuffer.indexOf('\n')
        while (newlineIdx >= 0) {
            val line = lineBuffer.substring(0, newlineIdx).trim()
            lineBuffer.delete(0, newlineIdx + 1)
            
            if (line.isNotEmpty()) {
                processLine(line)
            }
            
            newlineIdx = lineBuffer.indexOf('\n')
        }
        
        // Prevent buffer overflow (discard if too long without newline)
        if (lineBuffer.length > 1024) {
            Log.w(TAG, "⚠️ Line buffer overflow, clearing")
            lineBuffer.clear()
        }
    }
    
    // Process a complete line, check if it's a valid command
    private fun processLine(line: String) {
        Log.d(TAG, "📋 Processing line: '$line'")
        
        // Check if this is a valid command
        val cmd = line.uppercase().trim()
        
        // Handle RESET_GAME as RESET for compatibility
        val normalizedCmd = when (cmd) {
            "RESET_GAME" -> "RESET"
            else -> cmd
        }
        
        if (VALID_COMMANDS.contains(normalizedCmd)) {
            Log.d(TAG, "🎮 Valid command detected: $normalizedCmd")
            sendCommand(normalizedCmd)
        } else if (line.startsWith("[")) {
            // Debug/log message from ESP32, just log it
            sendDebug("ESP32: $line")
        } else {
            Log.d(TAG, "📝 Non-command line: $line")
        }
    }
    
    // Send a command event to Flutter
    private fun sendCommand(cmd: String) {
        Log.d(TAG, "📤 COMMAND: $cmd")
        handler.post {
            eventSink?.success(mapOf("type" to "command", "data" to cmd))
        }
    }
    
    private fun writeUsb(text: String) {
        if (!isConnected || usbConnection == null || writeEndpoint == null) {
            sendDebug("❌ No conectado o sin endpoint de escritura")
            return
        }
        
        executor.execute {
            try {
                val data = text.toByteArray(Charsets.UTF_8)
                val sent = usbConnection?.bulkTransfer(writeEndpoint, data, data.size, 1000) ?: -1
                
                if (sent > 0) {
                    bytesSent += sent
                    val hex = data.joinToString(" ") { "%02X".format(it) }
                    Log.d(TAG, "📤 Sent $sent bytes: $hex")
                    sendDebug("📤 TX($sent): $text")
                    
                    handler.post {
                        eventSink?.success(mapOf(
                            "type" to "tx",
                            "data" to text,
                            "length" to sent
                        ))
                    }
                } else {
                    sendDebug("❌ Error enviando: $sent")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Send error: ${e.message}", e)
                sendDebug("❌ Error: ${e.message}")
            }
        }
    }
    
    private fun disconnect() {
        Log.d(TAG, "🔌 disconnect()")
        isReading = false
        isConnected = false
        
        try {
            usbConnection?.close()
        } catch (e: Exception) {
            Log.e(TAG, "close error: ${e.message}")
        }
        
        usbConnection = null
        usbDevice = null
        readEndpoint = null
        writeEndpoint = null
        
        sendStatus(false)
        sendDebug("🔌 Desconectado")
    }
}
