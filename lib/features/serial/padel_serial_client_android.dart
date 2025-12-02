// lib/features/serial/padel_serial_client_android.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

/// Cliente para comunicación RS-485 en Android (TV Box)
/// 
/// Usa el paquete usb_serial que soporta módulos USB-Serial en Android:
/// - FTDI (FT232, FT2232, etc.)
/// - CH340/CH341
/// - CP210x
/// - PL2303
/// 
/// Protocolo idéntico a la versión de escritorio:
/// 10 bytes [P S ver devLo devHi C cmd seq crcLo crcHi]
class PadelSerialClientAndroid {
  static const int _baudRate = 115200;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  
  UsbPort? _port;
  UsbDevice? _device;
  StreamSubscription<UsbEvent>? _statusSub;
  Timer? _reconnectTimer;
  
  bool _isConnected = false;
  bool _isDisposed = false;
  final List<int> _buffer = [];

  /// Stream de comandos recibidos: formato "cmd:devId:seq"
  final _commandsCtrl = StreamController<String>.broadcast(sync: false);
  Stream<String> get commands => _commandsCtrl.stream;

  /// Estado de conexión
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  
  /// Dispositivos conocidos
  final Set<int> _knownDeviceIds = {};
  
  /// Historial de secuencias para deduplicación
  final Map<int, Set<int>> _seqHistory = {};
  final Map<int, int> _lastCmdTime = {};
  
  static const int _cmdCooldownUs = 300000; // 300ms

  PadelSerialClientAndroid();

  /// Inicializar cliente y buscar dispositivo USB-Serial
  Future<void> init() async {
    if (_isDisposed) return;
    
    try {
      // Escuchar eventos de conexión/desconexión USB
      _statusSub ??= UsbSerial.usbEventStream?.listen((UsbEvent event) {
        if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
          if (kDebugMode) print('[SERIAL] USB conectado');
          _connectToDevice();
        } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
          if (kDebugMode) print('[SERIAL] USB desconectado');
          _disconnect();
          _scheduleReconnect();
        }
      });

      await _connectToDevice();
      
    } catch (e) {
      if (kDebugMode) print('[SERIAL] Error init: $e');
      _scheduleReconnect();
    }
  }

  /// Buscar y conectar a dispositivo USB-Serial
  Future<void> _connectToDevice() async {
    if (_isDisposed || _isConnected) return;
    
    try {
      final devices = await UsbSerial.listDevices();
      
      if (devices.isEmpty) {
        if (kDebugMode) print('[SERIAL] No hay dispositivos USB-Serial');
        _scheduleReconnect();
        return;
      }

      // Buscar dispositivo compatible (FTDI, CH340, etc.)
      for (final device in devices) {
        if (kDebugMode) {
          print('[SERIAL] Dispositivo encontrado:');
          print('  VID: 0x${device.vid?.toRadixString(16)}');
          print('  PID: 0x${device.pid?.toRadixString(16)}');
          print('  Nombre: ${device.productName}');
        }
        
        // Intentar conectar
        if (await _connectToUsbDevice(device)) {
          _device = device;
          break;
        }
      }
      
    } catch (e) {
      if (kDebugMode) print('[SERIAL] Error buscando dispositivos: $e');
      _scheduleReconnect();
    }
  }

  /// Conectar a un dispositivo USB específico
  Future<bool> _connectToUsbDevice(UsbDevice device) async {
    try {
      final port = await device.create();
      if (port == null) {
        if (kDebugMode) print('[SERIAL] No se pudo crear puerto');
        return false;
      }

      // Solicitar permiso (solo primera vez)
      final hasPermission = await port.open();
      if (!hasPermission) {
        if (kDebugMode) print('[SERIAL] Sin permiso para acceder al dispositivo');
        return false;
      }

      // Configurar parámetros seriales
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        _baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _port = port;
      _isConnected = true;
      isConnected.value = true;

      if (kDebugMode) {
        print('[SERIAL] ✅ Conectado a ${device.productName}');
        print('[SERIAL] Configuración: $_baudRate 8N1');
      }

      // Iniciar lectura de datos
      _startReading();
      
      return true;
      
    } catch (e) {
      if (kDebugMode) print('[SERIAL] Error conectando: $e');
      return false;
    }
  }

  /// Iniciar lectura de datos del puerto
  void _startReading() {
    if (_port == null) return;

    _port!.inputStream?.listen(
      (Uint8List data) {
        _buffer.addAll(data);
        _processBuffer();
      },
      onError: (error) {
        if (kDebugMode) print('[SERIAL] Error lectura: $error');
        _disconnect();
        _scheduleReconnect();
      },
      onDone: () {
        if (kDebugMode) print('[SERIAL] Stream cerrado');
        _disconnect();
        _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  /// Procesar buffer de datos recibidos
  void _processBuffer() {
    while (_buffer.length >= 10) {
      // Buscar inicio de paquete ('P' 'S')
      final startIdx = _findPacketStart();
      if (startIdx == -1) {
        _buffer.clear();
        return;
      }

      // Eliminar datos antes del inicio
      if (startIdx > 0) {
        _buffer.removeRange(0, startIdx);
      }

      // Verificar que hay un paquete completo
      if (_buffer.length < 10) return;

      // Extraer paquete
      final packet = Uint8List.fromList(_buffer.sublist(0, 10));
      _buffer.removeRange(0, 10);

      // Procesar paquete
      _processPacket(packet);
    }
  }

  /// Buscar inicio de paquete en buffer
  int _findPacketStart() {
    for (int i = 0; i < _buffer.length - 1; i++) {
      if (_buffer[i] == 0x50 && _buffer[i + 1] == 0x53) {
        return i;
      }
    }
    return -1;
  }

  /// Procesar paquete de 10 bytes
  void _processPacket(Uint8List packet) {
    // Extraer campos
    final ver = packet[2];
    final devId = packet[3] | (packet[4] << 8);
    final cmd = packet[6];
    final seq = packet[7];
    final crcLo = packet[8];
    final crcHi = packet[9];
    
    // Validar CRC
    final calculatedCrc = _crc16Ccitt(packet.sublist(0, 8));
    final receivedCrc = crcLo | (crcHi << 8);
    
    if (calculatedCrc != receivedCrc) {
      if (kDebugMode) {
        print('[SERIAL] ❌ CRC inválido: calculado=0x${calculatedCrc.toRadixString(16)}, recibido=0x${receivedCrc.toRadixString(16)}');
      }
      return;
    }
    
    // Registrar dispositivo conocido
    _knownDeviceIds.add(devId);
    
    // Deduplicación por secuencia
    _seqHistory.putIfAbsent(devId, () => <int>{});
    if (_seqHistory[devId]!.contains(seq)) {
      if (kDebugMode) {
        print('[SERIAL] Duplicado ignorado: dev=0x${devId.toRadixString(16)} seq=$seq');
      }
      return;
    }
    _seqHistory[devId]!.add(seq);
    
    // Limpiar historial antiguo
    if (_seqHistory[devId]!.length > 30) {
      final toRemove = _seqHistory[devId]!.first;
      _seqHistory[devId]!.remove(toRemove);
    }
    
    final cmdChar = String.fromCharCode(cmd);
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    
    // Cooldown de 300ms
    final lastCmd = _lastCmdTime[devId] ?? 0;
    if (nowUs - lastCmd < _cmdCooldownUs) {
      if (kDebugMode) {
        print('[SERIAL] Comando ignorado (cooldown): dev=0x${devId.toRadixString(16)}');
      }
      return;
    }
    _lastCmdTime[devId] = nowUs;
    
    // Validar comandos válidos
    if (!['a', 'b', 'u', 'g'].contains(cmdChar)) {
      if (kDebugMode) {
        print('[SERIAL] Comando desconocido: $cmdChar (0x${cmd.toRadixString(16)})');
      }
      return;
    }
    
    // Emitir comando
    final output = '$cmdChar:$devId:$seq';
    _commandsCtrl.add(output);
    
    if (kDebugMode) {
      print('[SERIAL] ✅ Comando: $output (botón $cmdChar desde ESP32 #0x${devId.toRadixString(16)})');
    }
  }

  /// Calcular CRC16-CCITT
  int _crc16Ccitt(Uint8List data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= byte << 8;
      for (int i = 0; i < 8; i++) {
        if (crc & 0x8000 != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  /// Desconectar del puerto
  Future<void> _disconnect() async {
    _isConnected = false;
    isConnected.value = false;
    
    await _port?.close();
    _port = null;
    _buffer.clear();
  }

  /// Programar reconexión automática
  void _scheduleReconnect() {
    if (_isDisposed) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed) {
        if (kDebugMode) print('[SERIAL] Intentando reconectar...');
        _connectToDevice();
      }
    });
  }

  /// Liberar recursos
  Future<void> dispose() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    await _statusSub?.cancel();
    await _disconnect();
    await _commandsCtrl.close();
    isConnected.dispose();
  }
}
