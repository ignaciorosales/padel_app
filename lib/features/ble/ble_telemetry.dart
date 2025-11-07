// lib/features/ble/ble_telemetry.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Telemetría de latencia BLE: mide tiempo desde RX hasta comando emitido
class BleTelemetry {
  static const bool enabled = true; // ▲ Deshabilitar en producción si no se necesita

  // Historial circular de últimas 100 mediciones
  final _history = Queue<LatencyMeasurement>();
  static const _maxHistory = 100;

  // Estadísticas acumuladas
  int _totalMeasurements = 0;
  int _minLatencyUs = 999999999;
  int _maxLatencyUs = 0;
  int _sumLatencyUs = 0;

  // Contadores por tipo de comando
  final _countByCmd = <String, int>{};

  /// Registrar nueva medición
  void record(LatencyMeasurement measurement) {
    if (!enabled) return;

    _history.add(measurement);
    if (_history.length > _maxHistory) {
      _history.removeFirst();
    }

    _totalMeasurements++;
    _sumLatencyUs += measurement.totalLatencyUs;
    
    if (measurement.totalLatencyUs < _minLatencyUs) {
      _minLatencyUs = measurement.totalLatencyUs;
    }
    if (measurement.totalLatencyUs > _maxLatencyUs) {
      _maxLatencyUs = measurement.totalLatencyUs;
    }

    _countByCmd[measurement.cmd] = (_countByCmd[measurement.cmd] ?? 0) + 1;
  }

  /// Obtener estadísticas actuales
  TelemetryStats getStats() {
    if (_totalMeasurements == 0) {
      return TelemetryStats(
        totalMeasurements: 0,
        minLatencyUs: 0,
        maxLatencyUs: 0,
        avgLatencyUs: 0,
        p95LatencyUs: 0,
        recentMeasurements: const [],
        countByCmd: const {},
      );
    }

    // Calcular P95 (percentil 95)
    final sorted = _history.map((m) => m.totalLatencyUs).toList()..sort();
    final p95Index = (sorted.length * 0.95).floor();
    final p95 = sorted.isNotEmpty && p95Index < sorted.length 
        ? sorted[p95Index] 
        : _maxLatencyUs;

    return TelemetryStats(
      totalMeasurements: _totalMeasurements,
      minLatencyUs: _minLatencyUs,
      maxLatencyUs: _maxLatencyUs,
      avgLatencyUs: _sumLatencyUs ~/ _totalMeasurements,
      p95LatencyUs: p95,
      recentMeasurements: _history.toList(),
      countByCmd: Map.unmodifiable(_countByCmd),
    );
  }

  /// Resetear todas las estadísticas
  void reset() {
    _history.clear();
    _totalMeasurements = 0;
    _minLatencyUs = 999999999;
    _maxLatencyUs = 0;
    _sumLatencyUs = 0;
    _countByCmd.clear();
  }

  /// Log formateado de última medición (solo debug)
  void logLast() {
    if (!enabled || _history.isEmpty || !kDebugMode) return;
    
    final last = _history.last;
    final stages = <String>[];
    
    if (last.parseUs != null) {
      stages.add('parse=${last.parseUs}µs');
    }
    if (last.dedupUs != null) {
      stages.add('dedup=${last.dedupUs}µs');
    }
    if (last.cooldownUs != null) {
      stages.add('cooldown=${last.cooldownUs}µs');
    }
    
    debugPrint(
      '[⚡ TELEMETRY] ${last.cmd} | '
      'total=${last.totalLatencyUs}µs | '
      '${stages.join(" | ")} | '
      'devId=0x${last.devId.toRadixString(16)}'
    );
  }
}

/// Medición individual de latencia
class LatencyMeasurement {
  final int devId;
  final String cmd; // 'a', 'b', 'u', 'g'
  final int rxTimestampUs; // Microsegundos desde epoch
  final int emitTimestampUs; // Microsegundos desde epoch
  
  // Etapas opcionales (microsegundos)
  final int? parseUs;
  final int? dedupUs;
  final int? cooldownUs;

  LatencyMeasurement({
    required this.devId,
    required this.cmd,
    required this.rxTimestampUs,
    required this.emitTimestampUs,
    this.parseUs,
    this.dedupUs,
    this.cooldownUs,
  });

  int get totalLatencyUs => emitTimestampUs - rxTimestampUs;

  @override
  String toString() => 
      'Latency(cmd=$cmd, total=${totalLatencyUs}µs, dev=0x${devId.toRadixString(16)})';
}

/// Snapshot de estadísticas
class TelemetryStats {
  final int totalMeasurements;
  final int minLatencyUs;
  final int maxLatencyUs;
  final int avgLatencyUs;
  final int p95LatencyUs;
  final List<LatencyMeasurement> recentMeasurements;
  final Map<String, int> countByCmd;

  TelemetryStats({
    required this.totalMeasurements,
    required this.minLatencyUs,
    required this.maxLatencyUs,
    required this.avgLatencyUs,
    required this.p95LatencyUs,
    required this.recentMeasurements,
    required this.countByCmd,
  });

  String toSummary() {
    final ms = avgLatencyUs / 1000;
    final maxMs = maxLatencyUs / 1000;
    final p95Ms = p95LatencyUs / 1000;
    
    return 'Avg: ${ms.toStringAsFixed(2)}ms | '
           'Max: ${maxMs.toStringAsFixed(2)}ms | '
           'P95: ${p95Ms.toStringAsFixed(2)}ms | '
           'Samples: $totalMeasurements';
  }
}
