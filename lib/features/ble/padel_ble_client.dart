// lib/features/ble/padel_ble_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    show FlutterReactiveBle, DiscoveredDevice, BleStatus, ScanMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_telemetry.dart';

/// Frame broadcast por el ESP32:
/// 12B: [FF,FF,'P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi]
/// 10B: ['P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi]
/// cmd: 'p' (punto), 'u' (undo), 'g' (restart con doble pulsación)
/// legacy: 'a'/'b' (fw viejo) -> se mapean por equipo asignado.
class BleFrame {
  final int devId; // 0..65535
  final int seq;   // 1..255
  final int cmd;
  BleFrame({required this.devId, required this.seq, required this.cmd});
}

class DiscoveredRemote {
  final int devId;
  int rssi;
  DateTime lastSeen;
  DiscoveredRemote({
    required this.devId,
    required this.rssi,
    required this.lastSeen,
  });
}

class PairedRemote {
  final int devId;
  final String team; // 'blue' | 'red'
  PairedRemote({required this.devId, required this.team});
}

class PadelBleClient {
  // UI feedback para restart (sin lógica de serverSelect)
  final ValueNotifier<bool> restartArmed = ValueNotifier<bool>(false);
  final ValueNotifier<int?> restartDevId = ValueNotifier<int?>(null);

  // ▲ TELEMETRÍA: Medir latencias en tiempo real
  final telemetry = BleTelemetry();

  /// ▲ TEST HELPER: Inyectar comandos simulados (pasan por stream → bloc → UI)
  void emitTestCommand(String cmd) {
    _commandsCtrl.add(cmd);
  }

  late final StreamSubscription<BleStatus> _statusSub;
  bool _scanRestarting = false; // ▲ GUARD: Evitar carreras entre watchdog/lifecycle/status

  PadelBleClient({String targetName = "PadelScore-C3"}) : _targetName = targetName {
    _statusSub = _ble.statusStream.listen((s) async {
      if (kDebugMode) print('[BLE] status=$s');
      bleStatus.value = s;
      
      // ▲ AUTO-RESTART: Si BLE vuelve a estar ready y no tenemos scan activo, reiniciar
      if (s == BleStatus.ready && _scanSub == null) {
        if (kDebugMode) debugPrint('[BLE] Status ready, restarting scan...');
        await safeRestartScan();
      }
      // ▲ AUTO-STOP: Si BLE deja de estar ready, detener scan
      if (s != BleStatus.ready && _scanSub != null) {
        if (kDebugMode) debugPrint('[BLE] Status not ready, stopping scan...');
        await stopListening();
      }
    });
  }

  static const int _protoVer = 0x01;
  
  // ========== OPTIMIZACIÓN LATENCIA ==========
  static const bool _verbose = false; // Solo para debugging extremo
  static const int _minRssi = -95; // Filtrar ruido débil
  
  // ========== WATCHDOG ANTI-STALL ==========
  DateTime _lastRx = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdog;
  Timer? _periodicKick;
  static const _stallThreshold = Duration(seconds: 20); // Considerar stalled si no hay frames en 20s
  static const _watchdogInterval = Duration(seconds: 7); // Verificar cada 7s
  static const _periodicRestart = Duration(minutes: 10); // Restart preventivo cada 10min

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final String _targetName;

  StreamSubscription<DiscoveredDevice>? _scanSub;

  // === Streams públicos ===
  /// Emite: 'a','b','u','g' y comandos especiales tipo 'cmd:toggle-server'
  /// sync: true = procesamiento inmediato sin microtask queue (latencia crítica)
  final _commandsCtrl = StreamController<String>.broadcast(sync: true);
  Stream<String> get commands => _commandsCtrl.stream;

  final _discoveredCtrl = StreamController<List<DiscoveredRemote>>.broadcast();
  Stream<List<DiscoveredRemote>> get discoveredRemotes => _discoveredCtrl.stream;

  final _pairedCtrl = StreamController<List<PairedRemote>>.broadcast();
  Stream<List<PairedRemote>> get pairedDevices => _pairedCtrl.stream;

  final _advCtrl = StreamController<String>.broadcast();
  Stream<String> get advLog => _advCtrl.stream;

  final _rawFramesCtrl = StreamController<BleFrame>.broadcast();
  Stream<BleFrame> get rawFrames => _rawFramesCtrl.stream;

  // Estado expuesto
  final ValueNotifier<BleStatus?> bleStatus = ValueNotifier<BleStatus?>(null);
  final ValueNotifier<bool> discoveryArmed = ValueNotifier<bool>(false);

  // deviceId -> 'blue' | 'red'
  final Map<int, String> _teamByDev = <int, String>{};

  // Dedup + warm-up por dispositivo
  final _lastSeqByDev = <int, int>{};
  final _lastCmdTimeByDev = <int, DateTime>{}; // Anti-duplicación inteligente
  final _lastCmdByDev = <int, int>{}; // Último comando procesado
  static const _minCmdInterval = Duration(milliseconds: 300); // 300ms = permite rallies rápidos
  
  // ▲ FIFO queue-based seq deduplication: O(1) en lugar de O(n)
  final _processedSeqs = <int, List<int>>{}; // deviceId -> Queue circular de seqs procesados
  static const _maxSeqHistory = 30; // Mantener últimos 30 seqs
  final _seqHeadIndex = <int, int>{}; // deviceId -> índice circular del head
  
  // === ANTI-DOBLE PUNTO: 4 segundos entre puntos por dispositivo ===
  final _lastPointTimeByDev = <int, DateTime>{}; // Timestamp del último punto
  static const _pointCooldown = Duration(seconds: 4); // 4s entre puntos

  // === TELEMETRY: Timestamps parciales para medir latencia total ===
  final _telemetryPendingRx = <int, int>{}; // devId -> rxTimestamp (µs)
  final _telemetryPendingParse = <int, int>{}; // devId -> parseLatency (µs)
  final _telemetryPendingDedup = <int, int>{}; // devId -> dedupLatency (µs)
  final _telemetryPendingCooldown = <int, int>{}; // devId -> cooldownLatency (µs)

  // Cache de descubrimiento
  final _discovered = <int, DiscoveredRemote>{};

  // Snapshots para initialData en la UI
  List<PairedRemote> _pairedCache = const [];
  List<DiscoveredRemote> _discCache = const [];
  List<PairedRemote> get pairedSnapshot => List.unmodifiable(_pairedCache);
  List<DiscoveredRemote> get discoveredSnapshot => List.unmodifiable(_discCache);

  // === Restart simplificado: G (armar) + U (confirmar) ===
  static const _restartWindow = Duration(seconds: 4);
  int? _restartPendingDev;
  Timer? _restartTimer;

  Timer? _discoverTimer;
  Timer? _discoverPushTimer; // ▲ Timer para actualizar UI de descubrimiento sin bloquear hot path

  // ===================== Persistencia =====================

  Future<void> _loadPersisted() async {
    try {
      final p = await SharedPreferences.getInstance();
      final teamMapStr = p.getString('teams_map') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(teamMapStr));
      _teamByDev
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(int.parse(k, radix: 16), (v as String))));
    } catch (e, st) {
      // ▲ CRASH SAFETY: Si falla la carga, mantener vacío (no crashear la app)
      if (kDebugMode) {
        debugPrint('[BLE] ⚠️ Error loading persisted teams: $e');
        debugPrint('[BLE] Stack trace: $st');
        debugPrint('[BLE] Starting with empty team map...');
      }
      _teamByDev.clear();
    }
  }

  Future<void> _saveTeams() async {
    try {
      final p = await SharedPreferences.getInstance();
      final map = _teamByDev.map((k, v) => MapEntry(k.toRadixString(16), v));
      await p.setString('teams_map', jsonEncode(map));
    } catch (e) {
      // ▲ CRASH SAFETY: Si falla el guardado, loguear pero no crashear
      if (kDebugMode) {
        debugPrint('[BLE] ⚠️ Error saving teams: $e');
      }
    }
  }

  void _publishPaired() {
    final list = _teamByDev.entries
        .map((e) => PairedRemote(devId: e.key, team: e.value))
        .toList()
      ..sort((a, b) => a.devId.compareTo(b.devId));
    _pairedCache = list;
    _pairedCtrl.add(list);
  }

  Future<void> init() async {
    try {
      await _loadPersisted();
      // Inicializar queues circulares de seq dedup para todos los dispositivos pareados
      for (final devId in _teamByDev.keys) {
        _processedSeqs[devId] = List<int>.filled(_maxSeqHistory, -1); // -1 = slot vacío
        _seqHeadIndex[devId] = 0;
        _lastPointTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(0); // Epoch = permite primer punto
      }
      _publishPaired();
      _startWatchdog();
    } catch (e, st) {
      // ▲ CRASH SAFETY: Si falla init, continuar con estado vacío
      if (kDebugMode) {
        debugPrint('[BLE] ⚠️ Error during init: $e');
        debugPrint('[BLE] Stack trace: $st');
        debugPrint('[BLE] Continuing with empty state...');
      }
      _startWatchdog(); // Watchdog debe iniciarse siempre
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      // ▲ SYNC callback: No usar async/await para evitar contención con _onDevice
      // Si BLE no está ready, no hacer nada
      if (bleStatus.value != BleStatus.ready) return;

      final idle = DateTime.now().difference(_lastRx);
      if (idle > _stallThreshold) {
        // Scan stalled: reiniciar (sin await, lanzar en microtask)
        if (kDebugMode) {
          debugPrint('[BLE WATCHDOG] 🚨 Scan stalled (${idle.inSeconds}s sin frames), reiniciando...');
        }
        Future.microtask(() => safeRestartScan());
      }
    });
  }

  /// ▲ SAFE RESTART: Evita carreras cuando múltiples cosas piden restart
  Future<void> safeRestartScan() async {
    if (_scanRestarting) {
      if (kDebugMode) debugPrint('[BLE] Restart already in progress, skipping...');
      return;
    }
    _scanRestarting = true;
    try {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
      await startListening();
    } finally {
      _scanRestarting = false;
    }
  }

  Future<void> refreshPaired() async {
    await _loadPersisted();
    _publishPaired();
  }

  // ===================== Scan continuo (advertising) =====================

  Future<void> startListening() async {
    if (_scanSub != null) return;
    await _ensurePermissions();
    
    // Marcar inicio de scan como última recepción
    _lastRx = DateTime.now();
    
    // ▲ ESCANEO AGRESIVO: Máxima frecuencia para capturar todos los paquetes
    //   - ScanMode.lowLatency: escaneo continuo sin delays
    //   - requireLocationServicesEnabled: false para evitar bloqueos en algunos dispositivos
    _scanSub = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,  // ← CRÍTICO para alcance máximo
      requireLocationServicesEnabled: false,
    ).listen(
      _onDevice,
      onError: (e, st) => kDebugMode ? print('[BLE] scan error: $e') : null,
      cancelOnError: false,
    );
    
    // ▲ PERIODIC RESTART: Reinicio preventivo cada 10 minutos (vendor quirks)
    _periodicKick?.cancel();
    _periodicKick = Timer.periodic(_periodicRestart, (_) async {
      if (kDebugMode) debugPrint('[BLE] 🔄 Periodic scan restart (preventive)');
      await safeRestartScan();
    });
    
    if (kDebugMode) print('[BLE] 🚀 Escaneo agresivo activado (LOW_LATENCY + watchdog + periodic)');
  }

  Future<void> stopListening() async {
    await _scanSub?.cancel();
    _scanSub = null;
    _periodicKick?.cancel();
    _periodicKick = null;
    clearDiscovered();
  }

  /// ▲ ASYNC DISPOSE: Espera a que cierre el scan correctamente
  Future<void> dispose() async {
    _watchdog?.cancel();
    _watchdog = null;
    await stopListening();
    await _statusSub.cancel();
    await _commandsCtrl.close();
    await _discoveredCtrl.close();
    await _pairedCtrl.close();
    await _advCtrl.close();
    await _rawFramesCtrl.close();
    restartArmed.dispose();
    restartDevId.dispose();
  }

  // ===================== Pairing / equipos =====================

  Future<void> pairAs(int devId, String team) async {
    _teamByDev[devId] = (team == 'blue') ? 'blue' : 'red';
    _processedSeqs[devId] = List<int>.filled(_maxSeqHistory, -1); // Queue circular
    _seqHeadIndex[devId] = 0;
    _lastPointTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(0); // Epoch = permite primer punto
    await _saveTeams();
    _publishPaired();
    _discovered.remove(devId);
    _pushDiscovered();
  }

  Future<void> unpair(int devId) async {
    _teamByDev.remove(devId);
    _lastSeqByDev.remove(devId);
    _lastCmdTimeByDev.remove(devId);
    _lastCmdByDev.remove(devId);
    _processedSeqs.remove(devId); // Limpiar queue de seq dedup
    _seqHeadIndex.remove(devId); // Limpiar índice circular
    _lastPointTimeByDev.remove(devId); // Limpiar timestamp de punto
    await _saveTeams();
    _publishPaired();
  }

  bool isPaired(int devId) => _teamByDev.containsKey(devId);
  String? teamOf(int devId) => _teamByDev[devId];

  // ===================== UI de descubrimiento =====================

  void armDiscovery({Duration window = const Duration(seconds: 20)}) {
    discoveryArmed.value = true;
    clearDiscovered();
    _discoverTimer?.cancel();
    _discoverTimer = Timer(window, cancelDiscovery);
    
    // ▲ OPTIMIZACIÓN: Actualizar UI cada 500ms en lugar de en cada paquete BLE
    _discoverPushTimer?.cancel();
    _discoverPushTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pushDiscovered();
    });
  }

  void cancelDiscovery() {
    _discoverTimer?.cancel();
    _discoverTimer = null;
    _discoverPushTimer?.cancel();
    _discoverPushTimer = null;
    discoveryArmed.value = false;
    clearDiscovered();
  }

  void _pushDiscovered() {
    final now = DateTime.now();
    _discovered.removeWhere((_, v) => now.difference(v.lastSeen) > const Duration(seconds: 10));
    final list = _discovered.values.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    _discCache = list;
    _discoveredCtrl.add(list);
  }

  void clearDiscovered() {
    _discovered.clear();
    _discCache = const [];
    _discoveredCtrl.add(const []);
  }

  // ===================== Internals =====================

  Future<void> _ensurePermissions() async {
    final req = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (req.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      if (kDebugMode) print('[BLE] Warning: permissions denied -> $req');
    }
  }

  void _armRestart(int devId) {
    _restartTimer?.cancel();
    _restartPendingDev = devId;
    restartArmed.value = true;
    restartDevId.value = devId;
    _restartTimer = Timer(_restartWindow, () {
      if (kDebugMode) debugPrint('Restart: timeout (dev=0x${devId.toRadixString(16).padLeft(4, '0')})');
      _restartPendingDev = null;
      restartArmed.value = false;
      restartDevId.value = null;
    });
    if (kDebugMode) debugPrint('🔫 RESTART ARMADO: Presiona U (botón negro) para confirmar');
  }

  void _confirmRestart() {
    _restartTimer?.cancel();
    _restartPendingDev = null;
    restartArmed.value = false;
    restartDevId.value = null;
    _commandsCtrl.add('g'); // Emitir comando de restart
    if (kDebugMode) debugPrint('✅ REINICIO CONFIRMADO -> nuevo juego');
  }

  void _cancelRestart() {
    _restartTimer?.cancel();
    _restartPendingDev = null;
    restartArmed.value = false;
    restartDevId.value = null;
    if (kDebugMode) debugPrint('❌ REINICIO CANCELADO (presionaste P)');
  }

  bool _isPressForDiscovery(int cmd) {
    return cmd == 'p'.codeUnitAt(0) ||
           cmd == 'u'.codeUnitAt(0) ||
           cmd == 'g'.codeUnitAt(0) ||
           cmd == 'a'.codeUnitAt(0) || // legacy
           cmd == 'b'.codeUnitAt(0);   // legacy
  }

  /// Helper para emitir comando y registrar telemetría
  void _emitWithTelemetry(String cmd, int devId) {
    final emitUs = DateTime.now().microsecondsSinceEpoch;
    
    // Emitir comando al stream
    _commandsCtrl.add(cmd);
    
    // Registrar telemetría si hay datos pendientes
    final rxUs = _telemetryPendingRx[devId];
    if (rxUs != null && BleTelemetry.enabled) {
      final measurement = LatencyMeasurement(
        devId: devId,
        cmd: cmd,
        rxTimestampUs: rxUs,
        emitTimestampUs: emitUs,
        parseUs: _telemetryPendingParse[devId],
        dedupUs: _telemetryPendingDedup[devId],
        cooldownUs: _telemetryPendingCooldown[devId],
      );
      
      telemetry.record(measurement);
      
      // Log si verbose está activo
      if (kDebugMode && _verbose) {
        telemetry.logLast();
      }
      
      // Limpiar pending
      _telemetryPendingRx.remove(devId);
      _telemetryPendingParse.remove(devId);
      _telemetryPendingDedup.remove(devId);
      _telemetryPendingCooldown.remove(devId);
    }
  }

  void _onDevice(DiscoveredDevice d) {
    try {
      // ▲ TELEMETRY: Timestamp inicial (microsegundos)
      final int rxUs = DateTime.now().microsecondsSinceEpoch;
      
      // ▲ FILTRO RSSI: Descartar señales débiles (ruido) ANTES de parsear
      if (d.rssi < _minRssi) return;
      
      // ▲ WATCHDOG: Un solo timestamp en millis (más barato que DateTime múltiples)
      final int nowMs = rxUs ~/ 1000; // Reusar timestamp para watchdog
      _lastRx = DateTime.fromMillisecondsSinceEpoch(nowMs);
      
      final Uint8List md = d.manufacturerData;
      final int len = md.length;
      if (len == 0) return;

      // ▲ FAST-PATH PARSE: Tu FW emite EXACTO 12B o 10B (sin padding)
      BleFrame? frame;
      if (len == 12) {
        // 0xFF,0xFF,'P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi
        if (md[0] == 0xFF && md[1] == 0xFF && md[2] == 0x50 && md[3] == 0x53 && 
            md[4] == _protoVer && md[7] == 0x43) {
          final calc = _crc16Ccitt(md.sublist(2, 10));
          final rx = md[10] | (md[11] << 8);
          if (calc == rx) {
            final devId = md[5] | (md[6] << 8);
            frame = BleFrame(devId: devId, seq: md[9], cmd: md[8]);
          }
        }
      } else if (len == 10) {
        // 'P','S',ver,devLo,devHi,'C',cmd,seq,crcLo,crcHi
        if (md[0] == 0x50 && md[1] == 0x53 && md[2] == _protoVer && md[5] == 0x43) {
          final calc = _crc16Ccitt(md.sublist(0, 8));
          final rx = md[8] | (md[9] << 8);
          if (calc == rx) {
            final devId = md[3] | (md[4] << 8);
            frame = BleFrame(devId: devId, seq: md[7], cmd: md[6]);
          }
        }
      } else {
        return; // ▲ Longitud inesperada = no es nuestro protocolo
      }
      
      if (frame == null) return;
    
    // ▲ TELEMETRY: Tiempo de parse
    final int parseEndUs = DateTime.now().microsecondsSinceEpoch;
    final int parseUs = parseEndUs - rxUs;
    
    _rawFramesCtrl.add(frame);
    
    // ▲ VERBOSE LOG: Solo con flag explícito (comentar en producción)
    if (kDebugMode && _verbose) {
      print('[⚡ RX] dev=0x${frame.devId.toRadixString(16).padLeft(4, '0')} '
            'cmd=${String.fromCharCode(frame.cmd)} seq=${frame.seq} rssi=${d.rssi}');
    }

    final devId = frame.devId;
    final paired = isPaired(devId);

    // ===== WARM-UP: primera vez que vemos al device
    final seenBefore = _lastSeqByDev.containsKey(devId);
    if (!seenBefore) {
      _lastSeqByDev[devId] = frame.seq;
      _lastCmdTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(0);
      _lastCmdByDev[devId] = 0;

      // Descubrimiento si está armado y es pulsación válida
      if (discoveryArmed.value && _isPressForDiscovery(frame.cmd)) {
        _discovered[devId] = DiscoveredRemote(
          devId: devId, 
          rssi: d.rssi, 
          lastSeen: DateTime.fromMillisecondsSinceEpoch(nowMs)
        );
      }

      // Si NO está paireado, ignorar comandos
      if (!paired) return;
      
      // Si SÍ está paireado y es 'g', arma restart
      if (frame.cmd == 0x67) { // 'g'
        _armRestart(devId);
        return;
      }
    } else {
      // Ya visto antes: verificar si es nueva secuencia
      final lastSeq = _lastSeqByDev[devId]!;
      final isNewSeq = (lastSeq != frame.seq);
      
      // Descubrimiento (solo con nueva pulsación)
      if (discoveryArmed.value && isNewSeq && _isPressForDiscovery(frame.cmd)) {
        final prev = _discovered[devId];
        if (prev == null) {
          _discovered[devId] = DiscoveredRemote(
            devId: devId, 
            rssi: d.rssi, 
            lastSeen: DateTime.fromMillisecondsSinceEpoch(nowMs)
          );
        } else {
          prev.rssi = d.rssi;
          prev.lastSeen = DateTime.fromMillisecondsSinceEpoch(nowMs);
        }
      }
      
      _lastSeqByDev[devId] = frame.seq;
      
      // ▲ QUEUE-BASED DEDUP: Búsqueda lineal O(30) en queue circular
      final int dedupStartUs = DateTime.now().microsecondsSinceEpoch;
      final seqQueue = _processedSeqs[devId];
      if (seqQueue != null) {
        bool alreadyProcessed = false;
        for (int i = 0; i < _maxSeqHistory; i++) {
          if (seqQueue[i] == frame.seq) {
            alreadyProcessed = true;
            break;
          }
        }
        if (alreadyProcessed) return;
      }
      final int dedupUs = DateTime.now().microsecondsSinceEpoch - dedupStartUs;
      
      if (!isNewSeq) return; // Ráfaga duplicada
      
      // ▲ COOLDOWN: Aritmética de enteros (más rápido que DateTime.difference)
      final int cooldownStartUs = DateTime.now().microsecondsSinceEpoch;
      final lastCmdMs = _lastCmdTimeByDev[devId]!.millisecondsSinceEpoch;
      final lastCmd = _lastCmdByDev[devId]!;
      final deltaMs = nowMs - lastCmdMs;
      
      // Mismo comando en <300ms → BLOCK
      if (lastCmd == frame.cmd && deltaMs < _minCmdInterval.inMilliseconds) {
        return;
      }
      final int cooldownUs = DateTime.now().microsecondsSinceEpoch - cooldownStartUs;
      
      // Actualizar tracking
      _lastCmdTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(nowMs);
      _lastCmdByDev[devId] = frame.cmd;
      
      // ▲ TELEMETRY: Guardar timestamps parciales para medición final
      // (usamos variable temporal para evitar conflictos con otros comandos)
      _telemetryPendingParse[devId] = parseUs;
      _telemetryPendingDedup[devId] = dedupUs;
      _telemetryPendingCooldown[devId] = cooldownUs;
      _telemetryPendingRx[devId] = rxUs;
    }

    // ===== Restart simplificado: G (armar) + U (confirmar) =====
    if (frame.cmd == 0x67) { // 'g'
      if (!paired) return;
      _armRestart(devId);
      return;
    }

    // U (UNDO/RED button) confirma restart si está armado, sino hace UNDO normal
    if (frame.cmd == 0x75) { // 'u'
      if (!paired) return;
      
      if (_restartPendingDev == devId) {
        _confirmRestart();
        return;
      }
      
      _emitWithTelemetry('u', devId);
      
      // Marcar seq como procesada en queue circular
      final seqQueue = _processedSeqs[devId];
      if (seqQueue != null) {
        final headIdx = _seqHeadIndex[devId]!;
        seqQueue[headIdx] = frame.seq;
        _seqHeadIndex[devId] = (headIdx + 1) % _maxSeqHistory;
      }
      return;
    }

    // Cualquier comando 'p' del mismo mando cancela restart armado
    if (frame.cmd == 0x70 && _restartPendingDev == devId) { // 'p'
      _cancelRestart();
      return;
    }

    // ===== Scoring solo si pareado =====
    if (!paired) return;

    final team = _teamByDev[devId];

    // Preferido: 'p' => punto (mapeado por pairing)
    if (frame.cmd == 0x70) { // 'p'
      // ▲ ANTI-DOBLE PUNTO: Cooldown de 4s (aritmética de enteros)
      final lastPointMs = _lastPointTimeByDev[devId]?.millisecondsSinceEpoch ?? 0;
      final sincePointMs = nowMs - lastPointMs;
      
      if (sincePointMs < _pointCooldown.inMilliseconds) {
        if (kDebugMode && _verbose) {
          print('❌ [ANTI-DOBLE] Bloqueado dev=0x${devId.toRadixString(16)} '
                '(cooldown: ${_pointCooldown.inMilliseconds - sincePointMs}ms)');
        }
        return;
      }
      
      if (team == 'blue') _emitWithTelemetry('a', devId);
      else if (team == 'red') _emitWithTelemetry('b', devId);
      
      _lastPointTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(nowMs);
      
      // Marcar seq como procesada en queue circular
      final seqQueue = _processedSeqs[devId];
      if (seqQueue != null) {
        final headIdx = _seqHeadIndex[devId]!;
        seqQueue[headIdx] = frame.seq;
        _seqHeadIndex[devId] = (headIdx + 1) % _maxSeqHistory;
      }
      return;
    }

    // Legacy 'a'/'b': mapeamos por pairing
    if (frame.cmd == 0x61 || frame.cmd == 0x62) { // 'a' o 'b'
      if (team == 'blue') _emitWithTelemetry('a', devId);
      else if (team == 'red') _emitWithTelemetry('b', devId);
      
      // Marcar seq como procesada en queue circular
      final seqQueue = _processedSeqs[devId];
      if (seqQueue != null) {
        final headIdx = _seqHeadIndex[devId]!;
        seqQueue[headIdx] = frame.seq;
        _seqHeadIndex[devId] = (headIdx + 1) % _maxSeqHistory;
      }
      return;
    }
    } catch (e, st) {
      // ▲ CRASH SAFETY: Un error de parsing no debe matar el listener
      if (kDebugMode) {
        debugPrint('[BLE] ⚠️ Error en _onDevice: $e');
        debugPrint('[BLE] Stack trace: $st');
      }
    }
  }

  int _crc16Ccitt(Uint8List data) {
    int crc = 0xFFFF;
    for (final v in data) {
      crc ^= (v & 0xFF) << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        else                     crc = (crc << 1) & 0xFFFF;
      }
    }
    return crc & 0xFFFF;
  }
}
