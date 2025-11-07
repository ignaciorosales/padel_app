// lib/features/ble/ble_realtime_monitor.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
import 'package:Puntazo/features/ble/ble_telemetry.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/scoring/bloc/bloc_telemetry.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart'; // ▲ Para telemetría UI

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
  // MEJORA: Usar seq como key para correlación exacta (no timestamps arbitrarios)
  final Map<int, int> _bleCommandTimestamps = {}; // key = seq → rxTimestamp (µs)
  final List<E2EMeasurement> _e2eMeasurements = [];
  static const int _maxE2EMeasurements = 50;
  StreamSubscription<BleFrame>? _bleFrameSub;
  
  // ▲ TELEMETRÍA DEL BLOC
  BlocTelemetryStats? _blocStats;
  
  // ▲ TRACKING: Mapeo seq → cmd para correlación
  final Map<int, String> _seqToCmd = {}; // seq → 'a'/'b'/'u'/'g'
  
  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _isExpanded) {
        setState(() {
          _stats = widget.bleClient.telemetry.getStats();
          // Obtener stats del Bloc via context
          final bloc = context.read<ScoringBloc>();
          _blocStats = bloc.blocTelemetry.getStats();
        });
      }
    });
    
    // ▲ ESCUCHAR rawFrames: Capturar timestamp cuando llega comando BLE
    _bleFrameSub = widget.bleClient.rawFrames.listen((frame) {
      final rxUs = DateTime.now().microsecondsSinceEpoch;
      final cmd = String.fromCharCode(frame.cmd);
      
      // ▲ MEJORA: Usar seq como key para correlación exacta
      _bleCommandTimestamps[frame.seq] = rxUs;
      _seqToCmd[frame.seq] = cmd; // Guardar mapeo seq → cmd
      
      // ▼ DEBUG: Ver que estamos capturando comandos BLE con seq
      debugPrint('[📊 MONITOR] 🔵 BLE recibido: $cmd (seq: ${frame.seq}, dev: ${frame.devId}) - Pendientes: ${_bleCommandTimestamps.length}');
      
      // Limpiar timestamps antiguos (más de 2 segundos - timeout reducido)
      final seqsToRemove = <int>[];
      _bleCommandTimestamps.forEach((seq, timestamp) {
        final elapsed = rxUs - timestamp;
        if (elapsed > 2000000) { // 2s timeout
          seqsToRemove.add(seq);
        }
      });
      
      for (final seq in seqsToRemove) {
        _bleCommandTimestamps.remove(seq);
        _seqToCmd.remove(seq);
      }
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
      _blocStats = null;
      // Reset telemetría del Bloc
      context.read<ScoringBloc>().blocTelemetry.reset();
      // ▲ Reset telemetría de UI
      Scoreboard.resetUIStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoringBloc, ScoringState>(
      listener: (context, state) {
        final nowUs = DateTime.now().microsecondsSinceEpoch;
        
        // ▲ ESTRATEGIA SIMPLIFICADA: Procesar el seq más reciente que tengamos pendiente
        //   Asumimos que cada state update corresponde al último comando BLE recibido
        if (_bleCommandTimestamps.isNotEmpty) {
          // Ordenar por timestamp descendente (más reciente primero)
          final entries = _bleCommandTimestamps.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          final latestEntry = entries.first;
          final seq = latestEntry.key;
          final rxUs = latestEntry.value;
          final cmd = _seqToCmd[seq] ?? '?';
          
          // Calcular latencia end-to-end
          final e2eUs = nowUs - rxUs;
          final e2eMs = (e2eUs / 1000).toStringAsFixed(2);
          
          // ▼ DEBUG: Ver la medición E2E con seq
          debugPrint('[📊 MONITOR] ✅ E2E medido: seq=$seq cmd=$cmd → $e2eMs ms');
          
          final measurement = E2EMeasurement(
            cmd: cmd,
            seq: seq,
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
          
          // Remover el seq procesado
          _bleCommandTimestamps.remove(seq);
          _seqToCmd.remove(seq);
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
                            
                            // ========== TABLA UNIFICADA DE LATENCIAS ==========
                            if (_e2eMeasurements.isNotEmpty || (_stats != null && _stats!.totalMeasurements > 0)) ...[
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 16),
                              
                              // ▼ TABLA UNIFICADA: Pipeline completo con todas las etapas
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.withOpacity(0.15), Colors.purple.withOpacity(0.15)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withOpacity(0.4), width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // ========== HEADER ==========
                                    Row(
                                      children: [
                                        Icon(Icons.timeline, color: Colors.blue.shade300, size: 28),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '⚡ PIPELINE COMPLETO: BLE → UI',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Todas las etapas medidas en milisegundos (ms)',
                                                style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // ========== TABLA DE ETAPAS ==========
                                    _buildPipelineTable(),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // ========== ÚLTIMAS MEDICIONES ==========
                                    if (_e2eMeasurements.isNotEmpty) ...[
                                      const Divider(color: Colors.white24),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '📋 ÚLTIMAS MEDICIONES COMPLETAS',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${_e2eMeasurements.length} registros',
                                              style: const TextStyle(color: Colors.blue, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ..._e2eMeasurements.take(10).map((m) => _buildCompactMeasurementRow(m)),
                                    ],
                                  ],
                                ),
                              ),
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

  
  /// ▼ TABLA UNIFICADA: Muestra TODO el pipeline con tiempos correctos
  Widget _buildPipelineTable() {
    // Calcular promedios de cada etapa
    final bleAvgUs = _stats?.avgLatencyUs ?? 0;
    final blocAvgUs = _blocStats?.avgTotalUs ?? 0;
    final e2eAvgUs = _e2eMeasurements.isEmpty 
        ? 0 
        : (_e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a + b) / _e2eMeasurements.length).round();
    
    // Calcular el "gap" (tiempo no contabilizado)
    final accountedUs = bleAvgUs + blocAvgUs;
    final gapUs = e2eAvgUs - accountedUs;
    
    return Column(
      children: [
        // Header de la tabla
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'ETAPA DEL PIPELINE',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PROMEDIO',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  '% TOTAL',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // Fila 1: BLE (recepción + parseo)
        _buildPipelineRow(
          '1️⃣ BLE (RX + Parse)',
          bleAvgUs,
          e2eAvgUs,
          Colors.green,
          'ESP32 → Android BLE stack',
        ),
        
        // Fila 2: Bloc (procesamiento interno)
        _buildPipelineRow(
          '2️⃣ Bloc (Lógica scoring)',
          blocAvgUs,
          e2eAvgUs,
          Colors.purple,
          'onBleCommand + dispatch + onPointFor',
        ),
        
        // Fila 3: Gap (Flutter rendering + otras operaciones)
        _buildPipelineRow(
          '3️⃣ Flutter UI (Render)',
          gapUs > 0 ? gapUs : 0,
          e2eAvgUs,
          gapUs > 500000 ? Colors.red : gapUs > 100000 ? Colors.orange : Colors.blue,
          'Widget rebuild + repaint + frame',
        ),
        
        // Divisor
        Container(
          height: 2,
          color: Colors.white24,
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
        
        // Fila TOTAL
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  '⚡ TOTAL E2E',
                  style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${(e2eAvgUs / 1000).toStringAsFixed(2)} ms',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: e2eAvgUs > 100000 ? Colors.red : e2eAvgUs > 50000 ? Colors.orange : Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                flex: 2,
                child: Text(
                  '100%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // Nota explicativa
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gapUs > 500000
                      ? '⚠️ El 3️⃣ Flutter UI está tomando ${(gapUs / 1000).toStringAsFixed(1)} ms. Problema: widget rebuilds o animaciones pesadas.'
                      : e2eAvgUs > 50000
                          ? '⚠️ Latencia total > 50ms. Revisar animaciones y rebuilds.'
                          : '✅ Latencia total < 50ms. Rendimiento excelente.',
                  style: TextStyle(
                    color: gapUs > 500000 ? Colors.amber : Colors.green.shade300,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // ▲ TELEMETRÍA UI: Mostrar contadores de rebuilds
        const SizedBox(height: 16),
        _buildUIRebuildStats(),
      ],
    );
  }
  
  /// ▲ TELEMETRÍA UI: Visualización de rebuilds del scoreboard
  Widget _buildUIRebuildStats() {
    final uiStats = Scoreboard.getUIStats();
    final totalRebuilds = uiStats['total'] ?? 0;
    
    if (totalRebuilds == 0) {
      return const SizedBox.shrink(); // No mostrar si no hay datos
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets, color: Colors.purple, size: 16),
              const SizedBox(width: 8),
              const Text(
                '🎨 REBUILDS DE UI (Scoreboard Optimizado)',
                style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRebuildStat('Dígito Azul', uiStats['blue_digit'] ?? 0, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRebuildStat('Dígito Rojo', uiStats['red_digit'] ?? 0, Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRebuildStat('Juegos Set', uiStats['games'] ?? 0, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRebuildStat('Header', uiStats['header'] ?? 0, Colors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL REBUILDS:',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$totalRebuilds',
                  style: TextStyle(
                    color: totalRebuilds > 100 ? Colors.red : totalRebuilds > 50 ? Colors.orange : Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalRebuilds > 100
                ? '⚠️ Demasiados rebuilds. El scoreboard se está reconstruyendo más de lo necesario.'
                : totalRebuilds > 50
                    ? '⚠️ Rebuilds moderados. Considerar optimizaciones adicionales.'
                    : '✅ Rebuilds mínimos. Solo se actualiza lo necesario.',
            style: TextStyle(
              color: totalRebuilds > 100 ? Colors.red : totalRebuilds > 50 ? Colors.orange : Colors.green,
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRebuildStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
          ),
          Text(
            '$count',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPipelineRow(String label, int valueUs, int totalUs, Color color, String description) {
    final ms = (valueUs / 1000).toStringAsFixed(2);
    final percentage = totalUs > 0 ? ((valueUs / totalUs) * 100).toStringAsFixed(1) : '0.0';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$ms ms',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  '$percentage%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactMeasurementRow(E2EMeasurement m) {
    final ms = (m.totalUs / 1000).toStringAsFixed(2);
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(m.rxTimestampUs);
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    
    Color color = Colors.green;
    if (m.totalUs > 100000) { // > 100ms
      color = Colors.red;
    } else if (m.totalUs > 50000) { // > 50ms
      color = Colors.orange;
    }

    String emoji = '?';
    if (m.cmd == 'a') emoji = '🔵';
    else if (m.cmd == 'b') emoji = '🔴';
    else if (m.cmd == 'u') emoji = '↩️';
    else if (m.cmd == 'g') emoji = '🔄';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              timeStr,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$ms ms',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
  final int seq; // ▲ MEJORA: Incluir seq para correlación exacta
  final int rxTimestampUs; // Microsegundos cuando se recibió por BLE
  final int uiUpdateTimestampUs; // Microsegundos cuando se actualizó la UI
  final int totalUs; // Latencia total (µs)

  E2EMeasurement({
    required this.cmd,
    required this.seq,
    required this.rxTimestampUs,
    required this.uiUpdateTimestampUs,
    required this.totalUs,
  });
}
