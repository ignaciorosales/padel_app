// lib/features/ble/padel_ble_client.dart
// Broadcast/listen-only BLE client for PadelScore-C3.
// Scans advertisements (no GATT) and emits commands when it finds "CMD:<letter><seq>"
// inside Manufacturer Data. It does NOT connect/pair.
//
// Valid commands sent by the ESP32 sketch via Serial Monitor: a,b,u,g,m,s
// Example MD bytes: ff ff 43 4d 44 3a 61 02
//   = [0xFF,0xFF] + "CMD:" + 'a' + 0x02 (sequence)
//
// Usage (e.g., in HomePage.initState):
//   final _ble = PadelBleClient();             // optional: PadelBleClient(targetName: "PadelScore-C3")
//   _ble.startListening();
//   _cmdSub = _ble.commands.listen((cmd) { ... });

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    show FlutterReactiveBle, DiscoveredDevice, BleStatus;
import 'package:permission_handler/permission_handler.dart';

// (Optional placeholder for future scoreboard-in-ADV usage)
class ScoreUpdate {
  final int setsA, setsB, gamesA, gamesB;
  final bool isTieBreak;
  final int? tbA, tbB;
  final bool isDeuce;
  final String? advantageTeam;
  final int? ptsA, ptsB;
  final String rawHeader, rawPoints;
  const ScoreUpdate({
    required this.setsA,
    required this.setsB,
    required this.gamesA,
    required this.gamesB,
    required this.isTieBreak,
    this.tbA,
    this.tbB,
    required this.isDeuce,
    this.advantageTeam,
    this.ptsA,
    this.ptsB,
    required this.rawHeader,
    required this.rawPoints,
  });
}

class PadelBleClient {
  PadelBleClient({String targetName = "PadelScore-C3"})
      : _targetName = targetName {
    _ble.statusStream.listen((s) {
      if (kDebugMode) print('[BLE] status=$s');
      bleStatus.value = s;
    });
  }

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final String _targetName;

  StreamSubscription<DiscoveredDevice>? _scanSub;

  // Public streams
  final _cmdCtrl = StreamController<String>.broadcast(); // emits 'a','b','u','g','m','s'
  Stream<String> get commands => _cmdCtrl.stream;

  // Optional: log lines for debugging (ADV seen, hex dumps, parsed CMD)
  final _advCtrl = StreamController<String>.broadcast();
  Stream<String> get advLog => _advCtrl.stream;

  // State (for UI)
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<DiscoveredDevice?> lastDevice =
      ValueNotifier<DiscoveredDevice?>(null);
  final ValueNotifier<BleStatus?> bleStatus = ValueNotifier<BleStatus?>(null);

  // De-dup identical payloads per device (avoid firing on periodic rebroadcasts)
  final Map<String, Uint8List> _lastMdById = {};
  // NEW: per-device sequence tracking (1..255). Same seq -> ignore; new seq -> emit.
  final Map<String, int> _lastSeqById = {};

  // -----------------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------------
  Future<void> startListening() async {
    await _ensurePermissions();

    await _scanSub?.cancel();
    _scanSub = null;
    isScanning.value = true;

    // Scan with no service filter to reliably receive MD across devices/OEMs
    _scanSub = _ble.scanForDevices(withServices: []).listen(
      _handleAdvertisement,
      onError: (e, st) {
        if (kDebugMode) print('[BLE] scan error: $e');
        isScanning.value = false;
      },
      onDone: () => isScanning.value = false,
      cancelOnError: false,
    );
  }

  Future<void> stopListening() async {
    await _scanSub?.cancel();
    _scanSub = null;
    isScanning.value = false;
  }

  // Not supported in broadcast mode (no connection)
  Future<void> writeText(String text) async =>
      throw UnsupportedError('Broadcast mode does not support writes');
  Future<void> sendCommand(String cmd) => writeText(cmd);

  void dispose() {
    stopListening();
    _cmdCtrl.close();
    _advCtrl.close();
  }

  // -----------------------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------------------
  Future<void> _ensurePermissions() async {
    final req = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect, // some OEMs require this to scan
      Permission.locationWhenInUse, // many Android builds still require this ON for scanning
    ].request();

    if (req.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      if (kDebugMode) print('[BLE] Warning: some permissions denied -> $req');
    }
  }

  String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  void _handleAdvertisement(DiscoveredDevice d) {
    final md = d.manufacturerData;
    if (md.isEmpty) return;

    // (A) quick MD de-dup per device (identical bytes repeated rapidly)
    final prev = _lastMdById[d.id];
    if (prev != null && prev.length == md.length && listEquals(prev, md)) return;
    _lastMdById[d.id] = Uint8List.fromList(md);
    lastDevice.value = d;

    // (B) REQUIRE our company ID 0xFFFF (little-endian) at the start
    // Many stacks include the 2-byte company ID in manufacturerData (FRB does).
    final hasOurCompanyId = md.length >= 2 && md[0] == 0xFF && md[1] == 0xFF;
    if (!hasOurCompanyId) {
      // Optional: still allow by device name if it matches (helps on some stacks)
      final name = (d.name ?? '').trim();
      if (!name.toLowerCase().contains(_targetName.toLowerCase())) {
        if (kDebugMode) {
          final hex = _hex(md);
          _advCtrl.add(
              'ADV "${name.isEmpty ? "(no-name)" : name}" rssi=${d.rssi} mdLen=${md.length} (other vendor) md=$hex');
        }
        return;
      }
    }

    // (C) Find "CMD:" (43 4D 44 3A) anywhere after the 2-byte company ID
    int indexOf(Uint8List data, List<int> pat, {int start = 0}) {
      outer:
      for (int i = start; i <= data.length - pat.length; i++) {
        for (int j = 0; j < pat.length; j++) {
          if (data[i + j] != pat[j]) continue outer;
        }
        return i;
      }
      return -1;
    }

    const sig = [0x43, 0x4D, 0x44, 0x3A]; // "CMD:"
    final idx = indexOf(md, sig, start: 0);
    if (idx == -1) {
      if (kDebugMode) {
        _advCtrl.add('ADV "${d.name}" rssi=${d.rssi} md(no CMD): ${_hex(md)}');
      }
      return;
    }

    final after = idx + sig.length;
    if (after >= md.length) return;

    // Letter after "CMD:"
    final letter = String.fromCharCode(md[after]).toLowerCase();

    const valid = {'a', 'b', 'u', 'g', 'm', 's'};
    if (!valid.contains(letter)) return;

    // =================== NEW: read and use sequence byte ===================
    // Expected layout: [FF FF] "CMD:" <letter> <seq>
    int seq = 0;
    final seqIndex = after + 1;
    if (md.length > seqIndex) {
      seq = md[seqIndex]; // 1..255 by firmware; rebroadcasts reuse same seq
    }

    // Use sequence per device to ignore rebroadcasts (same seq), but accept
    // repeated commands immediately as long as seq changed.
    if (seq != 0) {
      final lastSeq = _lastSeqById[d.id];
      if (lastSeq != null && lastSeq == seq) {
        // Same payload seen again -> ignore
        return;
      }
      _lastSeqById[d.id] = seq;
    } else {
      // If firmware ever omitted seq (shouldn't), you could choose to ignore:
      // return;
      // or allow through (no dedup) — here we allow.
    }

    if (kDebugMode) {
      _advCtrl.add(
          'CMD:$letter seq=$seq from "${d.name}" (rssi ${d.rssi}) md=${_hex(md)}');
      print('[BLE] CMD:$letter seq=$seq from "${d.name}" (rssi=${d.rssi})');
    }
    _cmdCtrl.add(letter);
  }
}
