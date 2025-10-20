// lib/features/ble/padel_ble_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    show FlutterReactiveBle, DiscoveredDevice, BleStatus, ScanMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  PadelBleClient({String targetName = "PadelScore-C3"}) : _targetName = targetName {
    _ble.statusStream.listen((s) {
      if (kDebugMode) print('[BLE] status=$s');
      bleStatus.value = s;
    });
  }

  static const int _protoVer = 0x01;

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
  
  // Set-based seq deduplication: IMPOSIBLE marcar dos veces con mismo seq
  final _processedSeqs = <int, Set<int>>{}; // deviceId -> Set de seqs procesados
  static const _maxSeqHistory = 30; // Mantener últimos 30 seqs
  
  // === ANTI-DOBLE PUNTO: 4 segundos entre puntos por dispositivo ===
  final _lastPointTimeByDev = <int, DateTime>{}; // Timestamp del último punto
  static const _pointCooldown = Duration(seconds: 4); // 4s entre puntos

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

  // ===================== Persistencia =====================

  Future<void> _loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final teamMapStr = p.getString('teams_map') ?? '{}';
    final map = Map<String, dynamic>.from(jsonDecode(teamMapStr));
    _teamByDev
      ..clear()
      ..addAll(map.map((k, v) => MapEntry(int.parse(k, radix: 16), (v as String))));
  }

  Future<void> _saveTeams() async {
    final p = await SharedPreferences.getInstance();
    final map = _teamByDev.map((k, v) => MapEntry(k.toRadixString(16), v));
    await p.setString('teams_map', jsonEncode(map));
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
    await _loadPersisted();
    // Inicializar Sets de seq dedup para todos los dispositivos pareados
    for (final devId in _teamByDev.keys) {
      _processedSeqs[devId] = <int>{};
      _lastPointTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(0); // Epoch = permite primer punto
    }
    _publishPaired();
  }

  Future<void> refreshPaired() async {
    await _loadPersisted();
    _publishPaired();
  }

  // ===================== Scan continuo (advertising) =====================

  Future<void> startListening() async {
    if (_scanSub != null) return;
    await _ensurePermissions();
    
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
    
    if (kDebugMode) print('[BLE] 🚀 Escaneo agresivo activado (LOW_LATENCY)');
  }

  Future<void> stopListening() async {
    await _scanSub?.cancel();
    _scanSub = null;
    clearDiscovered();
  }

  void dispose() {
    stopListening();
    _commandsCtrl.close();
    _discoveredCtrl.close();
    _pairedCtrl.close();
    _advCtrl.close();
    _rawFramesCtrl.close();
    restartArmed.dispose();
    restartDevId.dispose();
  }

  // ===================== Pairing / equipos =====================

  Future<void> pairAs(int devId, String team) async {
    _teamByDev[devId] = (team == 'blue') ? 'blue' : 'red';
    _processedSeqs[devId] = <int>{}; // Inicializar Set para seq dedup
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
    _processedSeqs.remove(devId); // Limpiar Set de seq dedup
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
  }

  void cancelDiscovery() {
    _discoverTimer?.cancel();
    _discoverTimer = null;
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

  void _onDevice(DiscoveredDevice d) {
    final t0 = DateTime.now(); // ⏱️ Timestamp de recepción BLE
    final Uint8List md = d.manufacturerData;
    if (md.isEmpty) return;

    // ▲ OPTIMIZACIÓN: parsing rápido sin crear objetos innecesarios
    final frame = _parse(md);
    if (frame == null) return; // Silenciar logs de paquetes no coincidentes para reducir overhead
    
    _rawFramesCtrl.add(frame);
    
    // ▲ DEBUG SILENCIADO: Solo loguear en modo verbose (descomentar para activar)
    // if (kDebugMode) {
    //   final t1 = DateTime.now();
    //   final parseLatency = t1.difference(t0).inMicroseconds;
    //   debugPrint('[⏱️ RX] devId=0x${frame.devId.toRadixString(16).padLeft(4, '0')} '
    //              'cmd=${String.fromCharCode(frame.cmd)} seq=${frame.seq} rssi=${d.rssi} | '
    //              'parse=${parseLatency}µs');
    // }

    final devId = frame.devId;
    final now = DateTime.now();
    final paired = isPaired(devId);

    // ===== WARM-UP: primera vez que vemos al device
    //   Guardamos la seq para futura deduplicación
    final seenBefore = _lastSeqByDev.containsKey(devId);
    if (!seenBefore) {
      _lastSeqByDev[devId] = frame.seq;
      _lastCmdTimeByDev[devId] = DateTime.fromMillisecondsSinceEpoch(0); // Epoch = permite primera pulsación
      _lastCmdByDev[devId] = 0; // Sin comando previo
      if (kDebugMode) debugPrint('[WARM-UP] dev=0x${devId.toRadixString(16).padLeft(4, '0')} '
                                 'seq=${frame.seq} - primera vez visto');

      // Descubrimiento si está armado y es pulsación válida
      if (discoveryArmed.value && _isPressForDiscovery(frame.cmd)) {
        _discovered[devId] = DiscoveredRemote(devId: devId, rssi: d.rssi, lastSeen: now);
        _pushDiscovered();
      }

      // ▼ Si NO está paireado, ignorar comandos (solo permitir descubrimiento)
      if (!paired) {
        if (kDebugMode) debugPrint('[WARM-UP] dev not paired - ignoring command');
        return;
      }
      
      // ▼ Si SÍ está paireado y es 'g', arma restart
      if (frame.cmd == 'g'.codeUnitAt(0)) {
        _armRestart(devId);
        return;
      }
      
      // ▼ Continuar procesando comando normalmente (caerá en la lógica de scoring abajo)
    } else {
      // Ya visto antes: verificar si es nueva secuencia
      final lastSeq = _lastSeqByDev[devId]!;
      final isNewSeq = (lastSeq != frame.seq);
      
      // Descubrimiento (solo con nueva pulsación)
      if (discoveryArmed.value && isNewSeq && _isPressForDiscovery(frame.cmd)) {
        final prev = _discovered[devId];
        if (prev == null) {
          _discovered[devId] = DiscoveredRemote(devId: devId, rssi: d.rssi, lastSeen: now);
        } else {
          prev.rssi = d.rssi;
          prev.lastSeen = now;
        }
        _pushDiscovered();
      }
      
      _lastSeqByDev[devId] = frame.seq; // siempre avanzamos seq
      
      // ▲ SET-BASED DEDUP: Verificar si este seq ya fue procesado (BULLETPROOF)
      final processedSet = _processedSeqs[devId];
      if (processedSet != null && processedSet.contains(frame.seq)) {
        // Silencioso: paquete duplicado de ráfaga (normal, esperado)
        return; // ← IMPOSIBLE procesar mismo seq dos veces
      }
      
      if (!isNewSeq) {
        // Silencioso: seq ya visto (normal con ráfagas)
        return; // re-emisión: ignorar
      }
      
      // ▲ PROTECCIÓN ANTI-DOBLE: Cooldown de 300ms + validación de comando
      final lastCmdTime = _lastCmdTimeByDev[devId]!;
      final lastCmd = _lastCmdByDev[devId]!;
      final timeSinceLastCmd = now.difference(lastCmdTime);
      
      // Si es el MISMO comando en <300ms → BLOCK (claramente duplicado)
      if (lastCmd == frame.cmd && timeSinceLastCmd < _minCmdInterval) {
        // Silencioso: cooldown activo (normal)
        return; // ← BLOCK: mismo comando muy rápido = duplicado
      }
      
      // Actualizar tracking (ANTES de procesar, para que sea atómico)
      _lastCmdTimeByDev[devId] = now;
      _lastCmdByDev[devId] = frame.cmd;
    }

    // ===== Restart simplificado: G (armar) + U (confirmar) =====
    if (frame.cmd == 'g'.codeUnitAt(0)) {
      if (!paired) return;
      _armRestart(devId);
      return;
    }

    // U (UNDO/RED button) confirma restart si está armado, sino hace UNDO normal
    if (frame.cmd == 'u'.codeUnitAt(0)) {
      if (!paired) return;
      
      if (_restartPendingDev == devId) {
        // Confirmar restart
        _confirmRestart();
        return;
      }
      
      // ✅ UNDO normal: procesar comando
      _commandsCtrl.add('u');
      
      // ✅ Marcar seq como procesada DESPUÉS de emitir comando exitosamente
      final processedSet = _processedSeqs[devId]!;
      processedSet.add(frame.seq);
      if (processedSet.length > _maxSeqHistory) {
        final oldest = processedSet.first;
        processedSet.remove(oldest);
      }
      
      if (kDebugMode) {
        debugPrint('↩️ UNDO | dev=0x${devId.toRadixString(16).padLeft(4, '0')} seq=${frame.seq}');
      }
      return;
    }

    // Cualquier comando 'p' del mismo mando cancela restart armado
    if (frame.cmd == 'p'.codeUnitAt(0) && _restartPendingDev == devId) {
      _cancelRestart();
      return; // ✅ Cancelar restart SIN sumar punto
    }

    // ===== Scoring solo si pareado =====
    if (!paired) {
      // Silencioso: dispositivo no pareado (normal)
      return;
    }

    final team = _teamByDev[devId]; // 'blue' | 'red'

    // Preferido: 'p' => punto (mapeado por pairing)
    if (frame.cmd == 'p'.codeUnitAt(0)) {
      // ▲ ANTI-DOBLE PUNTO: Verificar cooldown de 4s
      final lastPointTime = _lastPointTimeByDev[devId];
      if (lastPointTime != null) {
        final timeSinceLastPoint = now.difference(lastPointTime);
        if (timeSinceLastPoint < _pointCooldown) {
          final remainingMs = (_pointCooldown - timeSinceLastPoint).inMilliseconds;
          if (kDebugMode) {
            debugPrint('❌ [ANTI-DOBLE] Punto BLOQUEADO dev=0x${devId.toRadixString(16).padLeft(4, '0')} '
                       '(cooldown: ${remainingMs}ms restantes)');
          }
          return; // Bloquear punto
        }
      }
      
      if (team == 'blue') _commandsCtrl.add('a');
      else if (team == 'red') _commandsCtrl.add('b');
      
      // ✅ Actualizar timestamp del último punto
      _lastPointTimeByDev[devId] = now;
      
      // ✅ Marcar seq como procesada DESPUÉS de emitir comando exitosamente
      final processedSet = _processedSeqs[devId]!;
      processedSet.add(frame.seq);
      if (processedSet.length > _maxSeqHistory) {
        final oldest = processedSet.first;
        processedSet.remove(oldest);
      }
      
      if (kDebugMode) {
        final latency = DateTime.now().difference(t0).inMicroseconds;
        debugPrint('✅ PUNTO $team | dev=0x${devId.toRadixString(16).padLeft(4, '0')} '
                   'seq=${frame.seq} | ${latency}µs');
      }
      return;
    }

    // Legacy 'a'/'b': ignoramos la letra y mapeamos por pairing
    if (frame.cmd == 'a'.codeUnitAt(0) || frame.cmd == 'b'.codeUnitAt(0)) {
      if (team == 'blue') _commandsCtrl.add('a');
      else if (team == 'red') _commandsCtrl.add('b');
      
      // Marcar seq como procesada
      final processedSet = _processedSeqs[devId]!;
      processedSet.add(frame.seq);
      if (processedSet.length > _maxSeqHistory) {
        final oldest = processedSet.first;
        processedSet.remove(oldest);
      }
      return;
    }
  }

  /// Parse 12B (con 0xFFFF) o 10B (sin company ID)
  BleFrame? _parse(Uint8List raw) {
    if (raw.length >= 12) {
      for (int off = 0; off <= raw.length - 12; off++) {
        if (raw[off] == 0xFF &&
            raw[off + 1] == 0xFF &&
            raw[off + 2] == 0x50 && // 'P'
            raw[off + 3] == 0x53 && // 'S'
            raw[off + 4] == _protoVer &&
            raw[off + 7] == 0x43) { // 'C'
          final calc = _crc16Ccitt(raw.sublist(off + 2, off + 10));
          final rx   = raw[off + 10] | (raw[off + 11] << 8);
          if (calc != rx) {
            if (kDebugMode) debugPrint('[PARSE] CRC fail: calc=0x${calc.toRadixString(16)} rx=0x${rx.toRadixString(16)}');
            continue;
          }
          final devId = raw[off + 5] | (raw[off + 6] << 8);
          final cmd   = raw[off + 8];
          final seq   = raw[off + 9];
          if (kDebugMode) {
            debugPrint('[PARSE] ✓ 12B: devId=0x${devId.toRadixString(16).padLeft(4, '0')} '
                       '(byte5=0x${raw[off + 5].toRadixString(16).padLeft(2, '0')} '
                       'byte6=0x${raw[off + 6].toRadixString(16).padLeft(2, '0')}) '
                       'cmd=${String.fromCharCode(cmd)} seq=$seq');
          }
          return BleFrame(devId: devId, seq: seq, cmd: cmd);
        }
      }
    }
    if (raw.length >= 10) {
      for (int off = 0; off <= raw.length - 10; off++) {
        if (raw[off] == 0x50 && // 'P'
            raw[off + 1] == 0x53 && // 'S'
            raw[off + 2] == _protoVer &&
            raw[off + 5] == 0x43) { // 'C'
          final calc = _crc16Ccitt(raw.sublist(off + 0, off + 8));
          final rx   = raw[off + 8] | (raw[off + 9] << 8);
          if (calc != rx) continue;
          final devId = raw[off + 3] | (raw[off + 4] << 8);
          final cmd   = raw[off + 6];
          final seq   = raw[off + 7];
          return BleFrame(devId: devId, seq: seq, cmd: cmd);
        }
      }
    }
    return null;
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
