import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// BLE Listener usando Platform Channels (Kotlin nativo)
/// Replica EXACTAMENTE la API vieja de Android que usa Python
class NativeBLEListener {
  static const platform = MethodChannel('com.padelapp/ble');
  static const eventChannel = EventChannel('com.padelapp/ble_events');
  
  // Streams
  final _commandController = StreamController<String>.broadcast(sync: true);
  final _debugController = StreamController<String>.broadcast(sync: true);
  
  Stream<String> get commands => _commandController.stream;
  Stream<String> get debugMessages => _debugController.stream;
  
  StreamSubscription? _eventSubscription;
  
  NativeBLEListener() {
    debugPrint('📱 [NativeBLEListener] Constructor called');
  }

  Future<void> start() async {
    debugPrint('📱 [NativeBLEListener] start() called');
    
    try {
      _debugController.add('Iniciando BLE nativo...');
      
      // Escuchar eventos desde Kotlin
      debugPrint('📱 [NativeBLEListener] Setting up EventChannel listener...');
      _eventSubscription = eventChannel.receiveBroadcastStream().listen(
        (event) {
          debugPrint('📱 [NativeBLEListener] Event received: $event');
          if (event is Map) {
            final type = event['type'] as String?;
            final data = event['data'] as String?;
            
            if (type == 'command' && data != null) {
              debugPrint('📱 [NativeBLEListener] Command: $data');
              _commandController.add(data);
            } else if (type == 'debug' && data != null) {
              debugPrint('📱 [NativeBLEListener] Debug: $data');
              _debugController.add(data);
            }
          }
        },
        onError: (error) {
          debugPrint('📱 [NativeBLEListener] ERROR: $error');
          _debugController.add('Error: $error');
        },
        onDone: () {
          debugPrint('📱 [NativeBLEListener] Stream DONE');
        },
      );
      
      debugPrint('📱 [NativeBLEListener] EventChannel listener set up');
      
      // Iniciar scan en Kotlin
      debugPrint('📱 [NativeBLEListener] Calling platform.invokeMethod("startScan")...');
      await platform.invokeMethod('startScan');
      debugPrint('📱 [NativeBLEListener] startScan completed');
      
    } on PlatformException catch (e) {
      debugPrint('📱 [NativeBLEListener] PlatformException: ${e.message}');
      _debugController.add('Error plataforma: ${e.message}');
    } catch (e) {
      debugPrint('📱 [NativeBLEListener] Exception: $e');
      _debugController.add('Error iniciando BLE: $e');
    }
  }

  Future<void> stop() async {
    debugPrint('📱 [NativeBLEListener] stop() called');
    try {
      await platform.invokeMethod('stopScan');
      await _eventSubscription?.cancel();
      await _commandController.close();
      await _debugController.close();
    } catch (e) {
      debugPrint('📱 [NativeBLEListener] Error stopping: $e');
    }
  }
}
