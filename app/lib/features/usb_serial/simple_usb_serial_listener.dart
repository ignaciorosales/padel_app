import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

/// USB Serial Listener SIMPLE - usa paquete usb_serial
/// Basado en la implementación probada que funciona con el ESP32
///
/// El **parsing** de esta clase (qué se considera comando válido) está probado
/// contra el hardware real y no debe tocarse. Lo que sí se corrigió es la
/// gestión de la conexión, que tenía tres fallos que en una instalación real
/// se manifiestan como "la app no recibe nada" sin más pistas:
///
///  1. Solo se intentaba conectar una vez al arrancar. Si el permiso USB de
///     Android estaba pendiente, o el maestro ya estaba enchufado antes de
///     abrir la app, no había reintento y se quedaba muerta para siempre.
///  2. Al cerrarse el stream (maestro reiniciado, cable flojo) solo se
///     escribía un log: `_isConnected` seguía en `true` indefinidamente.
///  3. No se distinguía "no hay dispositivo" de "hay dispositivo pero no
///     abre", que es casi siempre el permiso sin aceptar.
class SimpleUsbSerialListener {
  // Streams
  final _commandController = StreamController<String>.broadcast(sync: true);
  final _debugController = StreamController<String>.broadcast(sync: true);
  final _connectionController = StreamController<bool>.broadcast(sync: true);
  final _deviceCountController = StreamController<int>.broadcast(sync: true);

  Stream<String> get commands => _commandController.stream;
  Stream<String> get debugMessages => _debugController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;

  /// Número de dispositivos USB serie que ve Android. Permite distinguir
  /// "no hay nada enchufado" de "está enchufado pero no abre".
  Stream<int> get deviceCount => _deviceCountController.stream;

  UsbPort? _port;
  Transaction<String>? _transaction;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<UsbEvent>? _usbEventSub;
  Timer? _retryTimer;

  bool _isConnected = false;
  bool _stopped = false;
  bool _connecting = false;
  String _deviceName = '';
  int _lastDeviceCount = 0;
  String? _lastError;

  bool get isConnected => _isConnected;
  String get deviceName => _deviceName;
  int get lastDeviceCount => _lastDeviceCount;
  String? get lastError => _lastError;

  /// Cada cuánto se reintenta mientras no haya conexión.
  static const Duration _retryInterval = Duration(seconds: 3);

  SimpleUsbSerialListener();

  Future<void> start() async {
    _stopped = false;
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

    // Y seguir reintentando mientras no haya conexión. Sin esto, un permiso
    // USB aceptado DESPUÉS de arrancar la app no servía de nada.
    _startRetryTimer();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (_stopped || _isConnected || _connecting) return;
      _connectToFirstDevice();
    });
  }

  Future<void> _connectToFirstDevice() async {
    if (_stopped || _connecting || _isConnected) return;
    _connecting = true;
    try {
      final devices = await UsbSerial.listDevices();
      _lastDeviceCount = devices.length;
      _deviceCountController.add(devices.length);
      _sendDebug('${devices.length} dispositivos USB encontrados');

      if (devices.isEmpty) {
        _sendDebug('No hay dispositivos USB');
        _lastError = null;
        _connectionController.add(false);
        return;
      }

      // Intentar conectar a cada dispositivo
      for (final device in devices) {
        _sendDebug(
          'Probando vid=0x${device.vid?.toRadixString(16) ?? '?'} '
          'pid=0x${device.pid?.toRadixString(16) ?? '?'} '
          '${device.productName ?? ''}',
        );

        final port = await device.create();
        if (port == null) {
          _lastError = 'No se pudo crear el puerto para '
              '${device.productName ?? 'dispositivo'}';
          continue;
        }

        final opened = await port.open();
        if (!opened) {
          // Causa habitual: el permiso USB de Android no está concedido.
          _lastError = 'Permiso USB denegado o puerto ocupado '
              '(${device.productName ?? 'dispositivo'})';
          _sendDebug('No se pudo abrir el puerto: $_lastError');
          continue;
        }

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
        _lastError = null;

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
            _lastError = 'Error en stream: $e';
            // El puerto ya no sirve: soltarlo y dejar que el timer reintente.
            _disconnect();
          },
          onDone: () {
            _sendDebug('Stream cerrado');
            // ANTES esto solo se logueaba y la app se quedaba creyendo que
            // seguía conectada aunque el maestro se hubiera reiniciado.
            _disconnect();
          },
        );

        _isConnected = true;
        _connectionController.add(true);
        _sendDebug('Conectado a $_deviceName');
        return;
      }

      _sendDebug('No se pudo conectar a ningún dispositivo');
      _connectionController.add(false);
    } catch (e) {
      _lastError = 'Fallo al conectar: $e';
      _sendDebug(_lastError!);
      _connectionController.add(false);
    } finally {
      _connecting = false;
    }
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
    if (_debugController.isClosed) return;
    _debugController.add(msg);
  }

  void _disconnect() {
    _lineSub?.cancel();
    _lineSub = null;

    _transaction?.dispose();
    _transaction = null;

    _port?.close();
    _port = null;

    final wasConnected = _isConnected;
    _isConnected = false;
    _deviceName = '';
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    if (wasConnected) _sendDebug('Desconectado');
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
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _usbEventSub?.cancel();
    _disconnect();

    await _commandController.close();
    await _debugController.close();
    await _connectionController.close();
    await _deviceCountController.close();
  }
}
