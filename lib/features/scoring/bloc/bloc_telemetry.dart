// lib/features/scoring/bloc/bloc_telemetry.dart

import 'dart:async';

/// Telemetría para medir tiempos de procesamiento del Bloc
class BlocTelemetry {
  // Últimas mediciones
  final List<BlocLatencyMeasurement> _measurements = [];
  static const int _maxMeasurements = 50;
  
  /// Stream de mediciones para que el UI pueda escuchar
  final _measurementsController = StreamController<BlocLatencyMeasurement>.broadcast();
  Stream<BlocLatencyMeasurement> get measurements => _measurementsController.stream;
  
  void record(BlocLatencyMeasurement measurement) {
    _measurements.insert(0, measurement);
    if (_measurements.length > _maxMeasurements) {
      _measurements.removeLast();
    }
    _measurementsController.add(measurement);
  }
  
  BlocTelemetryStats getStats() {
    if (_measurements.isEmpty) {
      return BlocTelemetryStats(
        avgOnBleCommandUs: 0,
        avgDispatchUs: 0,
        avgOnPointForUs: 0,
        maxOnBleCommandUs: 0,
        maxDispatchUs: 0,
        maxOnPointForUs: 0,
        totalMeasurements: 0,
        recentMeasurements: [],
      );
    }
    
    final onBleCommandTimes = _measurements.map((m) => m.onBleCommandUs).where((t) => t > 0).toList();
    final dispatchTimes = _measurements.map((m) => m.dispatchUs).where((t) => t > 0).toList();
    final onPointForTimes = _measurements.map((m) => m.onPointForUs).where((t) => t > 0).toList();
    
    return BlocTelemetryStats(
      avgOnBleCommandUs: onBleCommandTimes.isEmpty ? 0 : (onBleCommandTimes.reduce((a, b) => a + b) / onBleCommandTimes.length).round(),
      avgDispatchUs: dispatchTimes.isEmpty ? 0 : (dispatchTimes.reduce((a, b) => a + b) / dispatchTimes.length).round(),
      avgOnPointForUs: onPointForTimes.isEmpty ? 0 : (onPointForTimes.reduce((a, b) => a + b) / onPointForTimes.length).round(),
      maxOnBleCommandUs: onBleCommandTimes.isEmpty ? 0 : onBleCommandTimes.reduce((a, b) => a > b ? a : b),
      maxDispatchUs: dispatchTimes.isEmpty ? 0 : dispatchTimes.reduce((a, b) => a > b ? a : b),
      maxOnPointForUs: onPointForTimes.isEmpty ? 0 : onPointForTimes.reduce((a, b) => a > b ? a : b),
      totalMeasurements: _measurements.length,
      recentMeasurements: _measurements.take(10).toList(),
    );
  }
  
  void reset() {
    _measurements.clear();
  }
  
  void dispose() {
    _measurementsController.close();
  }
}

/// Medición individual de latencias del Bloc
class BlocLatencyMeasurement {
  final String cmd;
  final int timestampUs;
  
  // Tiempos de cada etapa (en microsegundos)
  final int onBleCommandUs;  // Tiempo en _onBleCommand
  final int dispatchUs;      // Tiempo en _dispatchCmd
  final int onPointForUs;    // Tiempo en _onPointFor (o handler correspondiente)
  
  BlocLatencyMeasurement({
    required this.cmd,
    required this.timestampUs,
    required this.onBleCommandUs,
    required this.dispatchUs,
    required this.onPointForUs,
  });
  
  int get totalUs => onBleCommandUs + dispatchUs + onPointForUs;
}

/// Estadísticas agregadas de telemetría del Bloc
class BlocTelemetryStats {
  final int avgOnBleCommandUs;
  final int avgDispatchUs;
  final int avgOnPointForUs;
  final int maxOnBleCommandUs;
  final int maxDispatchUs;
  final int maxOnPointForUs;
  final int totalMeasurements;
  final List<BlocLatencyMeasurement> recentMeasurements;
  
  BlocTelemetryStats({
    required this.avgOnBleCommandUs,
    required this.avgDispatchUs,
    required this.avgOnPointForUs,
    required this.maxOnBleCommandUs,
    required this.maxDispatchUs,
    required this.maxOnPointForUs,
    required this.totalMeasurements,
    required this.recentMeasurements,
  });
  
  int get avgTotalUs => avgOnBleCommandUs + avgDispatchUs + avgOnPointForUs;
}
