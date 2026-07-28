import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

/// USB Serial Listener SIMPLE - usa paquete usb_serial
/// Basado en la implementación probada que funciona con el ESP32
class SimpleUsbSerialListener {
  // Streams
  final _commandController = StreamController<String>.broadcast(sync: true);
  final _debugController = StreamController<String>.broadcast(sync: true);
  final _connectionController = StreamController<bool>.broadcast(sync: true);
  
  Stream<String> get commands => _commandController.stream;
  Stream<String> get debugMessages => _debugController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  
  UsbPort? _port;
  Transaction<String>? _transaction;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<UsbEvent>? _usbEventSub;
  
  bool _isConnected = false;
  String _deviceName = '';
  
  bool get isConnected => _isConnected;
  String get deviceName => _deviceName;
  
  SimpleUsbSerialListener();

  Future<void> start() async {
    _sendDebug('Iniciando USB Serial...');
    
    // Escuchar eventos de conexión/desconexión USB
    _usbEventSub = UsbSerial.usbEventStream?.listen((event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        _sendDebug('Dispositivo USB conectado');
        _connectToFirstDevice();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        _sendDebug('Dispositivo USB desconectado');
        _disconnect();
      }
    });
    
    // Intentar conectar al inicio
    await _connectToFirstDevice();
  }

  Future<void> _connectToFirstDevice() async {
    final devices = await UsbSerial.listDevices();
    _sendDebug('${devices.length} dispositivos USB encontrados');
    
    if (devices.isEmpty) {
      _sendDebug('No hay dispositivos USB');
      _connectionController.add(false);
      return;
    }
    
    // Intentar conectar a cada dispositivo
    for (final device in devices) {
      final port = await device.create();
      if (port == null) continue;
      
      final opened = await port.open();
      if (!opened) continue;
      
      // Configurar puerto
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      
      _port = port;
      _deviceName = device.productName ?? 'USB Serial';
      
      // Crear Transaction con terminador de línea
      _transaction = Transaction.stringTerminated(
        port.inputStream!,
        Uint8List.fromList([10]), // 0x0A = newline
      );
      
      // Escuchar líneas completas
      _lineSub = _transaction!.stream.listen(
        _handleLine,
        onError: (e) {
          _sendDebug('Error en stream: $e');
        },
        onDone: () {
          _sendDebug('Stream cerrado');
        },
      );
      
      _isConnected = true;
      _connectionController.add(true);
      _sendDebug('Conectado a $_deviceName');
      return;
    }
    
    _sendDebug('No se pudo conectar a ningún dispositivo');
    _connectionController.add(false);
  }

  void _handleLine(String line) {
    final cmd = line.trim();
    if (cmd.isEmpty) return;
    
    // Filtrar mensajes de debug del ESP32
    if (cmd.startsWith('[')) {
      _sendDebug('ESP32: $cmd');
      return;
    }
    
    // Comandos válidos
    final validCommands = ['P_A', 'P_B', 'UNDO_A', 'UNDO_B', 'RESET', 'RESET_GAME', 'PONG'];
    final upperCmd = cmd.toUpperCase();

    // Nuevo protocolo basado en el ID de la caja: BTN:<idHex>:<P|U|G>
    // El master ya no decide el equipo; la app empareja caja → equipo.
    if (RegExp(r'^BTN:[0-9A-F]{1,4}:[PUG]$').hasMatch(upperCmd)) {
      _sendDebug('CMD: $upperCmd');
      _commandController.add(upperCmd);
      return;
    }

    if (validCommands.contains(upperCmd)) {
      _sendDebug('CMD: $upperCmd');
      
      // Normalizar RESET_GAME a RESET
      final normalizedCmd = upperCmd == 'RESET_GAME' ? 'RESET' : upperCmd;
      _commandController.add(normalizedCmd);
    }
  }

  void _sendDebug(String msg) {
    _debugController.add(msg);
  }

  void _disconnect() {
    _lineSub?.cancel();
    _lineSub = null;
    
    _transaction?.dispose();
    _transaction = null;
    
    _port?.close();
    _port = null;
    
    _isConnected = false;
    _deviceName = '';
    _connectionController.add(false);
    _sendDebug('Desconectado');
  }

  Future<void> send(String data) async {
    if (_port == null || !_isConnected) {
      _sendDebug('No conectado');
      return;
    }
    
    try {
      await _port!.write(Uint8List.fromList('$data\n'.codeUnits));
      _sendDebug('TX: $data');
    } catch (e) {
      _sendDebug('Error enviando: $e');
    }
  }

  Future<void> stop() async {
    _usbEventSub?.cancel();
    _disconnect();
    
    await _commandController.close();
    await _debugController.close();
    await _connectionController.close();
  }
}
