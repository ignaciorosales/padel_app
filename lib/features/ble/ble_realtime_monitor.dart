// lib/features/ble/ble_realtime_monitor.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
import 'package:Puntazo/features/ble/ble_telemetry.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// Monitor en tiempo real de comandos BLE REALES (sin botones de prueba)
/// Mide TODO el pipeline: BLE recepción → Stream → Bloc → UI actualizada
class BleRealtimeMonitor extends StatefulWidget {
  final PadelBleClient bleClient;

  const BleRealtimeMonitor({
    super.key,
    required this.bleClient,
  });

  @override
  State<BleRealtimeMonitor> createState() => _BleRealtimeMonitorState();
}

class _BleRealtimeMonitorState extends State<BleRealtimeMonitor> {
  bool _isExpanded = false;
  Timer? _updateTimer;
  TelemetryStats? _stats;
  final _scrollController = ScrollController();
  
  // ▲ MEDICIÓN END-TO-END: Capturar timestamp de cada comando BLE recibido
  final Map<String, int> _bleCommandTimestamps = {}; // key = "cmd-devId-rxUs" → rxTimestamp
  final List<E2EMeasurement> _e2eMeasurements = [];
  static const int _maxE2EMeasurements = 50;
  StreamSubscription<BleFrame>? _bleFrameSub;
  
  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _isExpanded) {
        setState(() {
          _stats = widget.bleClient.telemetry.getStats();
        });
      }
    });
    
    // ▲ ESCUCHAR rawFrames: Capturar timestamp cuando llega comando BLE
    _bleFrameSub = widget.bleClient.rawFrames.listen((frame) {
      final rxUs = DateTime.now().microsecondsSinceEpoch;
      final cmd = String.fromCharCode(frame.cmd);
      final key = '$cmd-${frame.devId}-$rxUs';
      _bleCommandTimestamps[key] = rxUs;
      
      // ▼ DEBUG: Ver que estamos capturando comandos BLE
      debugPrint('[📊 MONITOR] 🔵 BLE recibido: $cmd (dev: ${frame.devId}) - Pendientes: ${_bleCommandTimestamps.length}');
      
      // Limpiar timestamps antiguos (más de 10 segundos)
      _bleCommandTimestamps.removeWhere((k, v) {
        final elapsed = rxUs - v;
        return elapsed > 10000000; // 10s timeout
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _bleFrameSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      widget.bleClient.telemetry.reset();
      _stats = null;
      _e2eMeasurements.clear();
      _bleCommandTimestamps.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoringBloc, ScoringState>(
      listener: (context, state) {
        final nowUs = DateTime.now().microsecondsSinceEpoch;
        
        // ▼ DEBUG: Ver que estamos capturando actualizaciones de state
        debugPrint('[📊 MONITOR] 🎯 State actualizado - Pendientes: ${_bleCommandTimestamps.length}');
        
        // Procesar el comando BLE más antiguo pendiente
        if (_bleCommandTimestamps.isNotEmpty) {
          final oldest = _bleCommandTimestamps.entries.first;
          final key = oldest.key;
          final rxUs = oldest.value;
          final parts = key.split('-');
          final cmd = parts[0];
          
          // Calcular latencia end-to-end
          final e2eUs = nowUs - rxUs;
          final e2eMs = (e2eUs / 1000).toStringAsFixed(2);
          
          // ▼ DEBUG: Ver la medición E2E
          debugPrint('[📊 MONITOR] ✅ E2E medido: $cmd → $e2eMs ms');
          
          final measurement = E2EMeasurement(
            cmd: cmd,
            rxTimestampUs: rxUs,
            uiUpdateTimestampUs: nowUs,
            totalUs: e2eUs,
          );
          
          if (mounted) {
            setState(() {
              _e2eMeasurements.insert(0, measurement);
              if (_e2eMeasurements.length > _maxE2EMeasurements) {
                _e2eMeasurements.removeLast();
              }
            });
          }
          
          _bleCommandTimestamps.remove(key);
        }
      },
      child: Stack(
        children: [
        
        // Floating action button (📊) - Esquina SUPERIOR IZQUIERDA para mejor visibilidad
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'ble_realtime_monitor',
            mini: true,
            backgroundColor: Colors.blue.shade700,
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            child: const Icon(Icons.bar_chart, color: Colors.white),
          ),
        ),
        
        // Panel expandido - PANTALLA COMPLETA
        if (_isExpanded)
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.95),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header fijo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border(
                          bottom: BorderSide(color: Colors.blue.shade700.withOpacity(0.3), width: 2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bluetooth, color: Colors.blue.shade300, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'MONITOR BLE EN TIEMPO REAL',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white70),
                                onPressed: _reset,
                                tooltip: 'Reset',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: () => setState(() => _isExpanded = false),
                                tooltip: 'Cerrar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Contenido scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ========== RESUMEN RÁPIDO ==========
                            if (_stats != null && _stats!.totalMeasurements > 0) ...[
                              _buildQuickSummary(),
                              const SizedBox(height: 16),
                            ],
                            
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 16),
                            
                            // ========== LATENCIAS DETALLADAS ==========
                            const Text(
                              '📊 LATENCIAS BLE (milisegundos)',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            if (_stats != null && _stats!.totalMeasurements > 0) ...[
                              _buildLatencyCard('Promedio', _stats!.avgLatencyUs, Icons.show_chart, 1000, 3000),
                              const SizedBox(height: 8),
                              _buildLatencyCard('Mínimo', _stats!.minLatencyUs, Icons.south, 500, 1500),
                              const SizedBox(height: 8),
                              _buildLatencyCard('Máximo', _stats!.maxLatencyUs, Icons.north, 5000, 20000),
                              const SizedBox(height: 8),
                              _buildLatencyCard('P95 (Percentil 95)', _stats!.p95LatencyUs, Icons.analytics, 2000, 5000),
                            ] else
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.bluetooth_disabled, color: Colors.white38, size: 48),
                                    SizedBox(height: 12),
                                    Text(
                                      'Esperando comandos BLE...',
                                      style: TextStyle(color: Colors.white54, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Presiona botones en tus controles remotos',
                                      style: TextStyle(color: Colors.white38, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 16),
                            
                            // ========== CONTADORES DE COMANDOS ==========
                            if (_stats != null && _stats!.countByCmd.isNotEmpty) ...[
                              const Text(
                                '🎮 COMANDOS PROCESADOS',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCommandCounters(),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 16),
                            ],
                            
                            // ========== HISTORIAL DE MEDICIONES END-TO-END ==========
                            if (_e2eMeasurements.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.timeline, color: Colors.blue, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        '⚡ LATENCIAS COMPLETAS (BLE → UI)',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_e2eMeasurements.length} mediciones',
                                      style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tiempo desde recepción BLE hasta UI actualizada',
                                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 12),
                              // Estadísticas E2E
                              _buildE2EStats(),
                              const SizedBox(height: 16),
                              const Text(
                                'ÚLTIMAS MEDICIONES:',
                                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ..._e2eMeasurements.take(20).map((m) => _buildE2EMeasurementRow(m)),
                            ] else if (_stats != null && _stats!.recentMeasurements.isNotEmpty) ...[
                              // Fallback: mostrar solo latencias BLE si no hay E2E aún
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '📜 HISTORIAL BLE',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Últimas ${_stats!.recentMeasurements.length} mediciones',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._stats!.recentMeasurements.reversed.take(15).map((m) => _buildMeasurementRow(m)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary() {
    final avgMs = (_stats!.avgLatencyUs / 1000).toStringAsFixed(2);
    final maxMs = (_stats!.maxLatencyUs / 1000).toStringAsFixed(2);
    final total = _stats!.totalMeasurements;
    
    String status;
    Color statusColor;
    if (_stats!.avgLatencyUs < 2000) {
      status = 'EXCELENTE';
      statusColor = Colors.green;
    } else if (_stats!.avgLatencyUs < 5000) {
      status = 'BUENO';
      statusColor = Colors.blue;
    } else if (_stats!.avgLatencyUs < 10000) {
      status = 'ACEPTABLE';
      statusColor = Colors.orange;
    } else {
      status = 'LENTO';
      statusColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.speed, color: statusColor, size: 32),
              const SizedBox(width: 12),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Promedio', '$avgMs ms', Icons.trending_flat),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildQuickStat('Máximo', '$maxMs ms', Icons.trending_up),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildQuickStat('Total', '$total', Icons.confirmation_number),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLatencyCard(String label, int valueUs, IconData icon, int warningThreshold, int errorThreshold) {
    final ms = (valueUs / 1000).toStringAsFixed(2);
    Color color = Colors.green;
    String statusText = 'Excelente';
    
    if (valueUs > errorThreshold) {
      color = Colors.red;
      statusText = 'Problema';
    } else if (valueUs > warningThreshold) {
      color = Colors.orange;
      statusText = 'Revisar';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            '$ms ms',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCounters() {
    final countA = _stats!.countByCmd['a'] ?? 0;
    final countB = _stats!.countByCmd['b'] ?? 0;
    final countU = _stats!.countByCmd['u'] ?? 0;
    final countG = _stats!.countByCmd['g'] ?? 0;
    final total = countA + countB + countU + countG;

    return Row(
      children: [
        Expanded(child: _buildCommandCard('🔵 Azul', countA, total, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildCommandCard('🔴 Rojo', countB, total, Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _buildCommandCard('↩️ Undo', countU, total, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _buildCommandCard('🔄 Restart', countG, total, Colors.purple)),
      ],
    );
  }

  Widget _buildCommandCard(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(LatencyMeasurement m) {
    final ms = (m.totalLatencyUs / 1000).toStringAsFixed(2);
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(m.rxTimestampUs);
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    
    Color color = Colors.green;
    if (m.totalLatencyUs > 10000) {
      color = Colors.red;
    } else if (m.totalLatencyUs > 5000) {
      color = Colors.orange;
    }

    String emoji = '?';
    String cmdName = m.cmd.toUpperCase();
    if (m.cmd == 'a') {
      emoji = '🔵';
      cmdName = 'Azul';
    } else if (m.cmd == 'b') {
      emoji = '🔴';
      cmdName = 'Rojo';
    } else if (m.cmd == 'u') {
      emoji = '↩️';
      cmdName = 'Undo';
    } else if (m.cmd == 'g') {
      emoji = '🔄';
      cmdName = 'Restart';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              cmdName,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              timeStr,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          Text(
            '$ms ms',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildE2EStats() {
    if (_e2eMeasurements.isEmpty) return const SizedBox.shrink();
    
    final totalUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a + b);
    final avgUs = totalUs ~/ _e2eMeasurements.length;
    final minUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a < b ? a : b);
    final maxUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a > b ? a : b);
    
    // P95
    final sorted = _e2eMeasurements.map((m) => m.totalUs).toList()..sort();
    final p95Index = (sorted.length * 0.95).floor();
    final p95Us = sorted.isNotEmpty && p95Index < sorted.length ? sorted[p95Index] : maxUs;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildE2EStatItem('Promedio', avgUs, Icons.trending_flat),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildE2EStatItem('Mínimo', minUs, Icons.south),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildE2EStatItem('Máximo', maxUs, Icons.north),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildE2EStatItem('P95', p95Us, Icons.analytics),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildE2EStatItem(String label, int valueUs, IconData icon) {
    final ms = (valueUs / 1000).toStringAsFixed(2);
    
    Color color = Colors.green;
    if (valueUs > 20000) {
      color = Colors.red;
    } else if (valueUs > 10000) {
      color = Colors.orange;
    } else if (valueUs > 5000) {
      color = Colors.yellow.shade700;
    }
    
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          '$ms ms',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildE2EMeasurementRow(E2EMeasurement m) {
    final ms = (m.totalUs / 1000).toStringAsFixed(2);
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(m.rxTimestampUs);
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    
    Color color = Colors.green;
    if (m.totalUs > 20000) {
      color = Colors.red;
    } else if (m.totalUs > 10000) {
      color = Colors.orange;
    }

    String emoji = '?';
    String cmdName = m.cmd.toUpperCase();
    if (m.cmd == 'a') {
      emoji = '🔵';
      cmdName = 'Azul';
    } else if (m.cmd == 'b') {
      emoji = '🔴';
      cmdName = 'Rojo';
    } else if (m.cmd == 'u') {
      emoji = '↩️';
      cmdName = 'Undo';
    } else if (m.cmd == 'g') {
      emoji = '🔄';
      cmdName = 'Restart';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cmdName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$ms ms',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medición end-to-end de comandos BLE REALES
/// Desde recepción BLE hasta actualización de UI
class E2EMeasurement {
  final String cmd;
  final int rxTimestampUs; // Microsegundos cuando se recibió por BLE
  final int uiUpdateTimestampUs; // Microsegundos cuando se actualizó la UI
  final int totalUs; // Latencia total (µs)

  E2EMeasurement({
    required this.cmd,
    required this.rxTimestampUs,
    required this.uiUpdateTimestampUs,
    required this.totalUs,
  });
}
