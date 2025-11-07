// lib/features/ble/ble_full_telemetry_overlay.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
import 'package:Puntazo/features/ble/ble_telemetry.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// Overlay de telemetría COMPLETO que mide el pipeline end-to-end:
/// [Inyección de comando] → BLE stream → Bloc → State → UI render
/// 
/// Incluye botones para inyectar comandos simulados que pasan por TODO el proceso.
class BleFullTelemetryOverlay extends StatefulWidget {
  final Widget child;
  final PadelBleClient bleClient;

  const BleFullTelemetryOverlay({
    super.key,
    required this.child,
    required this.bleClient,
  });

  @override
  State<BleFullTelemetryOverlay> createState() => _BleFullTelemetryOverlayState();
}

class _BleFullTelemetryOverlayState extends State<BleFullTelemetryOverlay> {
  bool _isExpanded = false;
  Timer? _updateTimer;
  TelemetryStats? _stats;
  final _scrollController = ScrollController();
  
  // ▲ TELEMETRÍA END-TO-END: Medir comando → UI actualizada
  final Map<String, int> _pendingCommands = {}; // comando → timestamp injection (µs)
  final List<EndToEndMeasurement> _e2eMeasurements = [];
  static const int _maxE2EMeasurements = 20;
  
  // Debug: contador de updates
  int _stateUpdateCount = 0;
  int _commandInjectionCount = 0;
  
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
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _injectCommand(String cmd) {
    final injectionUs = DateTime.now().microsecondsSinceEpoch;
    
    // Marcar comando como pendiente para medir end-to-end
    final key = '$cmd-$injectionUs';
    _pendingCommands[key] = injectionUs;
    
    _commandInjectionCount++;
    debugPrint('[TELEMETRY] Inyectado comando #$_commandInjectionCount: $cmd (pendientes: ${_pendingCommands.length})');
    
    // Inyectar comando en el stream de BLE (pasa por TODA la lógica)
    _emitTestCommand(cmd);
  }

  /// Método helper para inyectar comandos de prueba directamente en el stream
  void _emitTestCommand(String cmd) {
    // Crear un measurement sintético para telemetría BLE
    final now = DateTime.now().microsecondsSinceEpoch;
    final fakeMeasurement = LatencyMeasurement(
      devId: 0xFFFF, // Device ID especial para comandos de prueba
      cmd: cmd,
      rxTimestampUs: now,
      emitTimestampUs: now + 50, // Simular 50µs de procesamiento BLE
      parseUs: 10,
      dedupUs: 10,
      cooldownUs: 10,
    );
    
    widget.bleClient.telemetry.record(fakeMeasurement);
    
    // Emitir al stream usando método público
    widget.bleClient.emitTestCommand(cmd);
  }

  void _reset() {
    setState(() {
      widget.bleClient.telemetry.reset();
      _e2eMeasurements.clear();
      _pendingCommands.clear();
      _stats = null;
      _stateUpdateCount = 0;
      _commandInjectionCount = 0;
    });
    debugPrint('[TELEMETRY] Reset completo');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Listener de Bloc para medir cuándo se actualiza el state
        BlocListener<ScoringBloc, ScoringState>(
          listener: (context, state) {
            _stateUpdateCount++;
            
            // Cuando el state cambia, verificar si hay comandos pendientes
            final now = DateTime.now().microsecondsSinceEpoch;
            
            debugPrint('[TELEMETRY] State update #$_stateUpdateCount - Pendientes: ${_pendingCommands.length}');
            
            if (_pendingCommands.isEmpty) return;
            
            // Procesar el comando pendiente más antiguo
            final entries = _pendingCommands.entries.toList();
            if (entries.isNotEmpty) {
              final oldest = entries.first;
              final key = oldest.key;
              final injectionUs = oldest.value;
              final elapsed = now - injectionUs;
              
              // Extraer comando original del key
              final cmd = key.split('-').first;
              
              if (elapsed > 5000000) {
                // Timeout: más de 5s
                debugPrint('[TELEMETRY] ⚠️ Timeout para comando $cmd (${elapsed / 1000}ms)');
                _pendingCommands.remove(key);
                return;
              }
              
              // Medir latencia end-to-end
              final e2eUs = now - injectionUs;
              final measurement = EndToEndMeasurement(
                cmd: cmd,
                injectionUs: injectionUs,
                stateUpdateUs: now,
                totalUs: e2eUs,
              );
              
              debugPrint('[TELEMETRY] ✅ Medido: $cmd → ${(e2eUs / 1000).toStringAsFixed(2)} ms');
              
              setState(() {
                _e2eMeasurements.insert(0, measurement);
                if (_e2eMeasurements.length > _maxE2EMeasurements) {
                  _e2eMeasurements.removeLast();
                }
              });
              
              _pendingCommands.remove(key);
            }
          },
          child: widget.child,
        ),
        
        // Floating action button (⚡)
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'ble_telemetry',
            mini: true,
            backgroundColor: Colors.amber.shade700,
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            child: const Icon(Icons.bolt, color: Colors.black),
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
                          bottom: BorderSide(color: Colors.white24, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '⚡ TELEMETRÍA COMPLETA',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ========== DEBUG INFO ==========
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🐛 DEBUG',
                              style: TextStyle(color: Colors.amber.shade300, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comandos inyectados: $_commandInjectionCount',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            Text(
                              'State updates: $_stateUpdateCount',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            Text(
                              'Comandos pendientes: ${_pendingCommands.length}',
                              style: TextStyle(
                                color: _pendingCommands.isEmpty ? Colors.green : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'E2E mediciones: ${_e2eMeasurements.length}',
                              style: TextStyle(
                                color: _e2eMeasurements.isEmpty ? Colors.red : Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      
                      // ========== BOTONES DE PRUEBA ==========
                      const Text(
                        'INYECTAR COMANDOS DE PRUEBA',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TestButton(
                            label: '🔵 Punto Azul (a)',
                            color: Colors.blue,
                            onPressed: () => _injectCommand('a'),
                          ),
                          _TestButton(
                            label: '🔴 Punto Rojo (b)',
                            color: Colors.red,
                            onPressed: () => _injectCommand('b'),
                          ),
                          _TestButton(
                            label: '↩️ Undo (u)',
                            color: Colors.orange,
                            onPressed: () => _injectCommand('u'),
                          ),
                          _TestButton(
                            label: '🔄 Restart (g)',
                            color: Colors.purple,
                            onPressed: () => _injectCommand('g'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      
                      // ========== LATENCIAS BLE ==========
                      const Text(
                        'LATENCIAS BLE (microsegundos)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (_stats != null) ...[
                        _buildLatencyRow('Promedio', _stats!.avgLatencyUs, 1000, 2000),
                        _buildLatencyRow('Mínimo', _stats!.minLatencyUs, 500, 1000),
                        _buildLatencyRow('Máximo', _stats!.maxLatencyUs, 5000, 10000),
                        _buildLatencyRow('P95', _stats!.p95LatencyUs, 1500, 3000),
                      ] else
                        const Text(
                          'No hay datos (presiona botones de prueba)',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Contadores de comandos BLE
                      if (_stats != null && _stats!.countByCmd.isNotEmpty) ...[
                        const Text(
                          'COMANDOS BLE PROCESADOS',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildCounter('🔵', _stats!.countByCmd['a'] ?? 0),
                            _buildCounter('🔴', _stats!.countByCmd['b'] ?? 0),
                            _buildCounter('↩️', _stats!.countByCmd['u'] ?? 0),
                            _buildCounter('🔄', _stats!.countByCmd['g'] ?? 0),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      
                      // ========== LATENCIAS END-TO-END ==========
                      const Text(
                        'LATENCIAS END-TO-END (inyección → UI)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      
                      if (_e2eMeasurements.isEmpty)
                        const Text(
                          'No hay mediciones (presiona botones de prueba)',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        )
                      else ...[
                        // Estadísticas agregadas
                        _buildE2EStats(),
                        const SizedBox(height: 8),
                        const Text(
                          'ÚLTIMAS MEDICIONES:',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        // Últimas 5 mediciones
                        ..._e2eMeasurements.take(5).map((m) => _buildE2EMeasurement(m)),
                      ],
                    ], // Cierra el children del Column principal
                  ), // Cierra el Column
                ), // Cierra el SingleChildScrollView
              ), // Cierra el Expanded
            ], // Cierra el children del Column de SafeArea
          ), // Cierra el Column de SafeArea
        ), // Cierra el SafeArea
      ), // Cierra el Material
    ), // Cierra el Positioned.fill
      ], // Cierra el children del Stack
    ); // Cierra el Stack
  }

  Widget _buildLatencyRow(String label, int valueUs, int warningThreshold, int errorThreshold) {
    final ms = valueUs / 1000;
    Color color = Colors.green;
    if (valueUs > errorThreshold) {
      color = Colors.red;
    } else if (valueUs > warningThreshold) {
      color = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            '${ms.toStringAsFixed(2)} ms',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String emoji, int count) {
    return Text(
      '$emoji $count',
      style: const TextStyle(color: Colors.white70, fontSize: 11),
    );
  }

  Widget _buildE2EStats() {
    if (_e2eMeasurements.isEmpty) return const SizedBox.shrink();
    
    final totalUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a + b);
    final avgUs = totalUs ~/ _e2eMeasurements.length;
    final minUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a < b ? a : b);
    final maxUs = _e2eMeasurements.map((m) => m.totalUs).reduce((a, b) => a > b ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          _buildLatencyRow('Promedio E2E', avgUs, 5000, 10000),
          _buildLatencyRow('Mínimo E2E', minUs, 3000, 5000),
          _buildLatencyRow('Máximo E2E', maxUs, 20000, 50000),
        ],
      ),
    );
  }

  Widget _buildE2EMeasurement(EndToEndMeasurement m) {
    final ms = m.totalUs / 1000;
    Color color = Colors.green;
    if (m.totalUs > 10000) {
      color = Colors.red;
    } else if (m.totalUs > 5000) {
      color = Colors.orange;
    }

    String emoji = '?';
    if (m.cmd == 'a') emoji = '🔵';
    else if (m.cmd == 'b') emoji = '🔴';
    else if (m.cmd == 'u') emoji = '↩️';
    else if (m.cmd == 'g') emoji = '🔄';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$emoji ${m.cmd.toUpperCase()}',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            '${ms.toStringAsFixed(2)} ms',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TestButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

/// Medición end-to-end: desde que se inyecta el comando hasta que se actualiza la UI
class EndToEndMeasurement {
  final String cmd;
  final int injectionUs; // Timestamp de inyección
  final int stateUpdateUs; // Timestamp cuando se actualizó el state
  final int totalUs; // Latencia total (µs)

  EndToEndMeasurement({
    required this.cmd,
    required this.injectionUs,
    required this.stateUpdateUs,
    required this.totalUs,
  });
}
