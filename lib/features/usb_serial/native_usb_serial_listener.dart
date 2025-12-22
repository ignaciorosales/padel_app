import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// USB Serial Listener usando Platform Channels (Kotlin nativo)
/// Recibe comandos del ESP32 via USB Serial
class NativeUsbSerialListener {
  static const platform = MethodChannel('com.padelapp/usb_serial');
  static const eventChannel = EventChannel('com.padelapp/usb_serial_events');
  
  // Streams
  final _commandController = StreamController<String>.broadcast(sync: true);
  final _debugController = StreamController<String>.broadcast(sync: true);
  final _connectionController = StreamController<bool>.broadcast(sync: true);
  
  Stream<String> get commands => _commandController.stream;
  Stream<String> get debugMessages => _debugController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  
  StreamSubscription? _eventSubscription;
  bool _isConnected = false;
  int _selectedDeviceId = -1;
  
  // Auto-reconnect settings
  Timer? _reconnectTimer;
  bool _autoReconnect = true;
  static const _reconnectInterval = Duration(seconds: 5);
  
  bool get isConnected => _isConnected;
  
  NativeUsbSerialListener() {
    debugPrint('🔌 [NativeUsbSerialListener] Constructor called');
  }

  Future<void> start() async {
    debugPrint('🔌 [NativeUsbSerialListener] start() called');
    
    try {
      _debugController.add('Iniciando USB Serial...');
      
      // Escuchar eventos desde Kotlin
      debugPrint('🔌 [NativeUsbSerialListener] Setting up EventChannel listener...');
      _eventSubscription = eventChannel.receiveBroadcastStream().listen(
        (event) {
          debugPrint('🔌 [NativeUsbSerialListener] Event received: $event');
          if (event is Map) {
            final type = event['type'] as String?;
            
            switch (type) {
              case 'command':
                final data = event['data'] as String?;
                if (data != null) {
                  debugPrint('🔌 [NativeUsbSerialListener] Command: $data');
                  _commandController.add(data);
                }
                break;
                
              case 'debug':
                final data = event['data'] as String?;
                if (data != null) {
                  debugPrint('🔌 [NativeUsbSerialListener] Debug: $data');
                  _debugController.add(data);
                }
                break;
                
              case 'status':
                final connected = event['connected'] as bool? ?? false;
                _isConnected = connected;
                _connectionController.add(connected);
                debugPrint('🔌 [NativeUsbSerialListener] Status: ${connected ? "CONNECTED" : "DISCONNECTED"}');
                
                // If disconnected and auto-reconnect is enabled, try to reconnect
                if (!connected && _autoReconnect) {
                  _scheduleReconnect();
                }
                break;
                
              case 'rx':
                // Raw data received - debug only
                final data = event['data'] as String? ?? '';
                _debugController.add('RX: $data');
                break;
                
              case 'devices':
                // Device list updated
                final devices = event['devices'] as List?;
                if (devices != null && devices.isNotEmpty) {
                  _debugController.add('${devices.length} dispositivos USB disponibles');
                  // Auto-connect to first device if not connected
                  if (!_isConnected && _autoReconnect) {
                    _tryAutoConnect(devices);
                  }
                }
                break;
            }
          }
        },
        onError: (error) {
          debugPrint('🔌 [NativeUsbSerialListener] ERROR: $error');
          _debugController.add('Error: $error');
        },
        onDone: () {
          debugPrint('🔌 [NativeUsbSerialListener] Stream DONE');
        },
      );
      
      debugPrint('🔌 [NativeUsbSerialListener] EventChannel listener set up');
      
      // Refresh device list and try to auto-connect
      await refreshDevices();
      
      debugPrint('🔌 [NativeUsbSerialListener] Setup completed');
      _debugController.add('USB Serial listener iniciado');
      
    } on PlatformException catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] PlatformException: ${e.message}');
      _debugController.add('Error plataforma: ${e.message}');
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] Exception: $e');
      _debugController.add('Error iniciando USB Serial: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> refreshDevices() async {
    try {
      final result = await platform.invokeMethod('getDevices');
      if (result is List) {
        final devices = result.map((d) => Map<String, dynamic>.from(d as Map)).toList();
        debugPrint('🔌 [NativeUsbSerialListener] ${devices.length} devices found');
        
        // Try auto-connect if not connected
        if (!_isConnected && _autoReconnect && devices.isNotEmpty) {
          _tryAutoConnect(devices);
        }
        
        return devices;
      }
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] refreshDevices error: $e');
      _debugController.add('Error listando dispositivos: $e');
    }
    return [];
  }
  
  void _tryAutoConnect(List devices) {
    if (_isConnected || devices.isEmpty) return;
    
    // Find a suitable device (ESP32 or serial adapter)
    for (var device in devices) {
      final deviceId = device['deviceId'] as int?;
      final productName = device['productName'] as String? ?? '';
      final vendorId = device['vendorId'] as int? ?? 0;
      
      // Prefer ESP32 devices (Espressif VID: 0x303A) or common serial adapters
      // CH340 VID: 0x1A86, CP210X VID: 0x10C4, FTDI VID: 0x0403
      final isLikelySerial = vendorId == 0x303A || // ESP32
                             vendorId == 0x1A86 || // CH340
                             vendorId == 0x10C4 || // CP210X
                             vendorId == 0x0403 || // FTDI
                             productName.toLowerCase().contains('serial') ||
                             productName.toLowerCase().contains('uart') ||
                             productName.toLowerCase().contains('usb');
      
      if (deviceId != null && isLikelySerial) {
        debugPrint('🔌 [NativeUsbSerialListener] Auto-connecting to: $productName (VID: 0x${vendorId.toRadixString(16)})');
        _debugController.add('Auto-conectando a $productName...');
        connect(deviceId);
        return;
      }
    }
    
    // Fallback: connect to first device
    final firstDevice = devices.first;
    final deviceId = firstDevice['deviceId'] as int?;
    if (deviceId != null) {
      debugPrint('🔌 [NativeUsbSerialListener] Auto-connecting to first device: $deviceId');
      _debugController.add('Auto-conectando al primer dispositivo...');
      connect(deviceId);
    }
  }
  
  Future<void> connect(int deviceId) async {
    try {
      _selectedDeviceId = deviceId;
      await platform.invokeMethod('connect', {'deviceId': deviceId});
      debugPrint('🔌 [NativeUsbSerialListener] connect() called for device $deviceId');
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] connect error: $e');
      _debugController.add('Error conectando: $e');
    }
  }
  
  Future<void> disconnect() async {
    try {
      _autoReconnect = false;
      _reconnectTimer?.cancel();
      await platform.invokeMethod('disconnect');
      debugPrint('🔌 [NativeUsbSerialListener] disconnect() called');
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] disconnect error: $e');
    }
  }
  
  Future<void> send(String data) async {
    try {
      await platform.invokeMethod('send', {'data': data});
      debugPrint('🔌 [NativeUsbSerialListener] sent: $data');
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] send error: $e');
      _debugController.add('Error enviando: $e');
    }
  }
  
  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectInterval, () async {
      if (_isConnected || !_autoReconnect) return;
      
      debugPrint('🔌 [NativeUsbSerialListener] Attempting reconnect...');
      _debugController.add('Intentando reconectar...');
      
      final devices = await refreshDevices();
      if (devices.isEmpty && _autoReconnect) {
        _scheduleReconnect();
      }
    });
  }
  
  void enableAutoReconnect(bool enabled) {
    _autoReconnect = enabled;
    if (!enabled) {
      _reconnectTimer?.cancel();
    }
  }

  Future<void> stop() async {
    debugPrint('🔌 [NativeUsbSerialListener] stop() called');
    try {
      _autoReconnect = false;
      _reconnectTimer?.cancel();
      await platform.invokeMethod('disconnect');
      await _eventSubscription?.cancel();
      await _commandController.close();
      await _debugController.close();
      await _connectionController.close();
    } catch (e) {
      debugPrint('🔌 [NativeUsbSerialListener] Error stopping: $e');
    }
  }
}
