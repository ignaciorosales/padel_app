// lib/features/ble/padel_ble_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    show FlutterReactiveBle, DiscoveredDevice, BleStatus;
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
  final ValueNotifier<bool> serverSelectActive = ValueNotifier<bool>(false);
  final ValueNotifier<int?> serverSelectDevId = ValueNotifier<int?>(null);

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
  final _commandsCtrl = StreamController<String>.broadcast();
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

  // Cache de descubrimiento
  final _discovered = <int, DiscoveredRemote>{};

  // Snapshots para initialData en la UI
  List<PairedRemote> _pairedCache = const [];
  List<DiscoveredRemote> _discCache = const [];
  List<PairedRemote> get pairedSnapshot => List.unmodifiable(_pairedCache);
  List<DiscoveredRemote> get discoveredSnapshot => List.unmodifiable(_discCache);

  // === Doble pulsación para restart ===
  static const _restartWindow = Duration(seconds: 4);
  int? _restartPendingDev;
  Timer? _restartTimer;

  // === Selección de servidor tras confirmar restart ===
  static const _srvSelectWindow = Duration(seconds: 4);
  bool _srvSelectActive = false;
  int? _srvSelectDev;
  Timer? _srvSelectTimer;

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
    _scanSub = _ble.scanForDevices(withServices: []).listen(
      _onDevice,
      onError: (e, st) => kDebugMode ? print('[BLE] scan error: $e') : null,
      cancelOnError: false,
    );
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
  }

  // ===================== Pairing / equipos =====================

  Future<void> pairAs(int devId, String team) async {
    _teamByDev[devId] = (team == 'blue') ? 'blue' : 'red';
    await _saveTeams();
    _publishPaired();
    _discovered.remove(devId);
    _pushDiscovered();
  }

  Future<void> unpair(int devId) async {
    _teamByDev.remove(devId);
    _lastSeqByDev.remove(devId);
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
    _restartTimer = Timer(_restartWindow, () {
      if (kDebugMode) debugPrint('Restart: timeout (dev=0x${devId.toRadixString(16).padLeft(4, '0')})');
      _restartPendingDev = null;
    });
    if (kDebugMode) debugPrint('Restart: armed for dev=0x${devId.toRadixString(16).padLeft(4, '0')}');
  }

  void _startServerSelect(int devId) {
    _srvSelectActive = true;
    _srvSelectDev = devId;
    _srvSelectTimer?.cancel();
    _srvSelectTimer = Timer(_srvSelectWindow, _finishServerSelect);

    // NEW: notify UI to show the popup
    serverSelectDevId.value = devId;
    serverSelectActive.value = true;

    if (kDebugMode) debugPrint('ServerSelect: active (press P to toggle; timeout to confirm)');
  }

  void _finishServerSelect() {
    _srvSelectTimer?.cancel();
    _srvSelectTimer = null;
    _srvSelectActive = false;
    _srvSelectDev = null;

    // NEW: tell UI to close
    serverSelectActive.value = false;
    serverSelectDevId.value = null;

    // Confirm and start the game
    _commandsCtrl.add('g');
    if (kDebugMode) debugPrint('ServerSelect: confirmed -> start new game');
  }

  void cancelServerSelect() {
    if (!_srvSelectActive) return;
    _srvSelectTimer?.cancel();
    _srvSelectActive = false;
    _srvSelectDev = null;
    serverSelectActive.value = false;
    serverSelectDevId.value = null;
  }

  void _cancelRestartIfFrom(int devId) {
    if (_restartPendingDev == devId) {
      _restartTimer?.cancel();
      _restartPendingDev = null;
      if (kDebugMode) debugPrint('Restart: canceled by other button from same device');
    }
  }

  bool _isPressForDiscovery(int cmd) {
    return cmd == 'p'.codeUnitAt(0) ||
           cmd == 'u'.codeUnitAt(0) ||
           cmd == 'g'.codeUnitAt(0) ||
           cmd == 'a'.codeUnitAt(0) || // legacy
           cmd == 'b'.codeUnitAt(0);   // legacy
  }

  void _onDevice(DiscoveredDevice d) {
    final Uint8List md = d.manufacturerData;
    if (md.isEmpty) return;

    final frame = _parse(md);
    if (frame == null) {
      if (kDebugMode) _advCtrl.add('ADV "${d.name}" rssi=${d.rssi} md(unmatched) ${_hex(md)}');
      return;
    }
    _rawFramesCtrl.add(frame);

    final devId = frame.devId;
    final now = DateTime.now();
    final paired = isPaired(devId);

    // ===== WARM-UP: primera vez que vemos al device => no ejecutar acción
    final seenBefore = _lastSeqByDev.containsKey(devId);
    if (!seenBefore) {
      _lastSeqByDev[devId] = frame.seq;

      // Descubrimiento si está armado y es pulsación válida
      if (discoveryArmed.value && _isPressForDiscovery(frame.cmd)) {
        _discovered[devId] = DiscoveredRemote(devId: devId, rssi: d.rssi, lastSeen: now);
        _pushDiscovered();
      }

      // Si es 'g' y está pareado, arma el restart
      if (paired && frame.cmd == 'g'.codeUnitAt(0)) _armRestart(devId);
      return;
    }

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
    if (!isNewSeq) return; // re-emisión

    // ===== Si estamos eligiendo servidor, interceptamos todo =====
    if (_srvSelectActive) {
      // Solo reacciona al mismo mando que confirmó el restart
      if (devId == _srvSelectDev) {
        if (frame.cmd == 'p'.codeUnitAt(0) ||
            frame.cmd == 'a'.codeUnitAt(0) || // legacy
            frame.cmd == 'b'.codeUnitAt(0)) {
          // Toggle de servidor en el Bloc
          _commandsCtrl.add('cmd:toggle-server');
          // reinicia ventana
          _srvSelectTimer?.cancel();
          _srvSelectTimer = Timer(_srvSelectWindow, _finishServerSelect);
          return;
        }
        if (frame.cmd == 'g'.codeUnitAt(0)) {
          // Confirmación inmediata
          _finishServerSelect();
          return;
        }
        if (frame.cmd == 'u'.codeUnitAt(0)) {
          // Cancelar selección y cancelar todo el restart
          _srvSelectTimer?.cancel();
          _srvSelectActive = false;
          _srvSelectDev = null;
          if (kDebugMode) debugPrint('ServerSelect: canceled');
          return;
        }
      }
      // Ignora otras pulsaciones (no damos puntos mientras se elige servidor)
      return;
    }

    // ===== Doble 'g' para restart (solo si pareado) =====
    if (frame.cmd == 'g'.codeUnitAt(0)) {
      if (!paired) return;
      if (_restartPendingDev == devId) {
        // Confirmado: entrar a elegir servidor
        _restartTimer?.cancel();
        _restartPendingDev = null;
        _startServerSelect(devId);
      } else {
        _armRestart(devId);
      }
      return;
    }

    // Cualquier otra pulsación del mismo mando cancela la ventana de restart
    _cancelRestartIfFrom(devId);

    // ===== Scoring solo si pareado =====
    if (!paired) {
      if (kDebugMode) {
        debugPrint('DROP (unpaired) dev=0x${devId.toRadixString(16).padLeft(4, '0')}');
      }
      return;
    }

    final team = _teamByDev[devId]; // 'blue' | 'red'

    // Preferido: 'p' => punto (mapeado por pairing)
    if (frame.cmd == 'p'.codeUnitAt(0)) {
      if (team == 'blue') _commandsCtrl.add('a');
      else if (team == 'red') _commandsCtrl.add('b');
      return;
    }

    // Legacy 'a'/'b': ignoramos la letra y mapeamos por pairing
    if (frame.cmd == 'a'.codeUnitAt(0) || frame.cmd == 'b'.codeUnitAt(0)) {
      if (team == 'blue') _commandsCtrl.add('a');
      else if (team == 'red') _commandsCtrl.add('b');
      return;
    }

    // Undo
    if (frame.cmd == 'u'.codeUnitAt(0)) {
      _commandsCtrl.add('u');
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
          if (calc != rx) continue;
          final devId = raw[off + 5] | (raw[off + 6] << 8);
          final cmd   = raw[off + 8];
          final seq   = raw[off + 9];
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

  String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}
