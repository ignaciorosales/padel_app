import 'dart:async';
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
  
  NativeBLEListener();

  Future<void> start() async {
    try {
      _debugController.add('Iniciando BLE nativo...');
      
      // Escuchar eventos desde Kotlin
      _eventSubscription = eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            final type = event['type'] as String?;
            final data = event['data'] as String?;
            
            if (type == 'command' && data != null) {
              _commandController.add(data);
            } else if (type == 'debug' && data != null) {
              _debugController.add(data);
            }
          }
        },
        onError: (error) {
          _debugController.add('Error: $error');
        },
      );
      
      // Iniciar scan en Kotlin
      await platform.invokeMethod('startScan');
      
    } catch (e) {
      _debugController.add('Error iniciando BLE: $e');
    }
  }

  Future<void> stop() async {
    try {
      await platform.invokeMethod('stopScan');
      await _eventSubscription?.cancel();
      await _commandController.close();
      await _debugController.close();
    } catch (e) {
      // ignore
    }
  }
}
