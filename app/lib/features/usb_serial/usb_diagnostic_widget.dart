import 'dart:async';
import 'package:flutter/material.dart';

/// Estados de diagnóstico del sistema USB Serial
enum UsbDiagnosticState {
  /// No hay dispositivo USB detectado
  noDevice,
  /// Dispositivo detectado pero no conectado
  deviceFound,
  /// Conectado pero sin datos
  connectedNoData,
  /// Conectado y recibiendo datos (debug/logs)
  connectedReceiving,
  /// Conectado y recibiendo COMANDOS válidos
  fullyOperational,
}

/// Modelo de diagnóstico USB
class UsbDiagnosticInfo {
  final UsbDiagnosticState state;
  final bool isConnected;
  final int bytesReceived;
  final int commandsReceived;
  final int packetsWithErrors;
  final String? lastCommand;
  final String? lastError;
  final String? deviceName;
  final DateTime? lastDataTime;
  final List<String> recentLogs;

  const UsbDiagnosticInfo({
    this.state = UsbDiagnosticState.noDevice,
    this.isConnected = false,
    this.bytesReceived = 0,
    this.commandsReceived = 0,
    this.packetsWithErrors = 0,
    this.lastCommand,
    this.lastError,
    this.deviceName,
    this.lastDataTime,
    this.recentLogs = const [],
  });

  UsbDiagnosticInfo copyWith({
    UsbDiagnosticState? state,
    bool? isConnected,
    int? bytesReceived,
    int? commandsReceived,
    int? packetsWithErrors,
    String? lastCommand,
    String? lastError,
    String? deviceName,
    DateTime? lastDataTime,
    List<String>? recentLogs,
  }) {
    return UsbDiagnosticInfo(
      state: state ?? this.state,
      isConnected: isConnected ?? this.isConnected,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      commandsReceived: commandsReceived ?? this.commandsReceived,
      packetsWithErrors: packetsWithErrors ?? this.packetsWithErrors,
      lastCommand: lastCommand ?? this.lastCommand,
      lastError: lastError ?? this.lastError,
      deviceName: deviceName ?? this.deviceName,
      lastDataTime: lastDataTime ?? this.lastDataTime,
      recentLogs: recentLogs ?? this.recentLogs,
    );
  }

  /// Tiempo desde la última recepción de datos
  Duration? get timeSinceLastData {
    if (lastDataTime == null) return null;
    return DateTime.now().difference(lastDataTime!);
  }

  /// ¿Está recibiendo datos activamente? (últimos 5 segundos)
  bool get isReceivingData {
    final elapsed = timeSinceLastData;
    return elapsed != null && elapsed.inSeconds < 5;
  }
}

/// Widget de diagnóstico USB compacto y no invasivo
/// Muestra un indicador de estado con opción de expandir para más detalles
class UsbDiagnosticWidget extends StatefulWidget {
  final ValueNotifier<UsbDiagnosticInfo> diagnosticNotifier;
  final VoidCallback? onTap;
  final bool startExpanded;

  const UsbDiagnosticWidget({
    super.key,
    required this.diagnosticNotifier,
    this.onTap,
    this.startExpanded = false,
  });

  @override
  State<UsbDiagnosticWidget> createState() => _UsbDiagnosticWidgetState();
}

class _UsbDiagnosticWidgetState extends State<UsbDiagnosticWidget> 
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.startExpanded;
    // Actualizar cada segundo para refrescar tiempos
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UsbDiagnosticInfo>(
      valueListenable: widget.diagnosticNotifier,
      builder: (context, info, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStateColor(info.state).withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getStateColor(info.state).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _isExpanded 
              ? _buildExpandedView(info)
              : _buildCompactView(info),
        );
      },
    );
  }

  Widget _buildCompactView(UsbDiagnosticInfo info) {
    return InkWell(
      onTap: () {
        setState(() => _isExpanded = true);
        widget.onTap?.call();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIndicator(info),
            const SizedBox(width: 8),
            Text(
              _getCompactStatusText(info),
              style: TextStyle(
                color: _getStateColor(info.state),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (info.commandsReceived > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${info.commandsReceived} cmds',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(UsbDiagnosticInfo info) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con botón de cerrar
          Row(
            children: [
              _buildStatusIndicator(info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔌 Diagnóstico USB Serial',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => setState(() => _isExpanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          const Divider(color: Colors.white24, height: 16),
          
          // // Estado actual
          // _buildStateCard(info),
          
          // const SizedBox(height: 8),
          
          // // Estadísticas
          // _buildStatsRow(info),
          
          // const SizedBox(height: 8),
          
          // Guía de troubleshooting
          _buildTroubleshootingHint(info),
          
          // Logs recientes (siempre visible)
          const SizedBox(height: 8),
          _buildRecentLogs(info),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(UsbDiagnosticInfo info) {
    final color = _getStateColor(info.state);
    final isActive = info.isReceivingData;
    
    return Stack(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: isActive ? 8 : 4,
                spreadRadius: isActive ? 2 : 0,
              ),
            ],
          ),
        ),
        if (isActive)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildStateCard(UsbDiagnosticInfo info) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _getStateColor(info.state).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStateColor(info.state).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStateIcon(info.state),
            color: _getStateColor(info.state),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStateTitle(info.state),
                  style: TextStyle(
                    color: _getStateColor(info.state),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (info.deviceName != null)
                  Text(
                    info.deviceName!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UsbDiagnosticInfo info) {
    return Row(
      children: [
        _buildStatItem('Bytes', '${info.bytesReceived}', Icons.download),
        const SizedBox(width: 12),
        _buildStatItem('Comandos', '${info.commandsReceived}', Icons.check_circle),
        const SizedBox(width: 12),
        _buildStatItem('Errores', '${info.packetsWithErrors}', Icons.error_outline,
            color: info.packetsWithErrors > 0 ? Colors.orange : null),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? Colors.white54),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingHint(UsbDiagnosticInfo info) {
    final hint = _getTroubleshootingHint(info);
    if (hint == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs(UsbDiagnosticInfo info) {
    // Mostrar hasta 20 logs recientes (los más nuevos primero)
    final logs = info.recentLogs.reversed.take(20).toList();
    
    return Container(
      height: 180, // Altura fija para permitir scroll
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Colors.white54, size: 12),
              const SizedBox(width: 4),
              const Text(
                'Log de comunicación:',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${info.recentLogs.length} msgs',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 8),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Sin logs aún...',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      // Colorear según tipo de mensaje
                      Color logColor = Colors.white70;
                      if (log.contains('✅')) {
                        logColor = Colors.green;
                      } else if (log.contains('⚠️')) {
                        logColor = Colors.orange;
                      } else if (log.contains('❌')) {
                        logColor = Colors.red;
                      } else if (log.contains('RX(')) {
                        logColor = Colors.cyan;
                      } else if (log.contains('TX(')) {
                        logColor = Colors.lightBlue;
                      } else if (log.contains('🎮')) {
                        logColor = Colors.greenAccent;
                      } else if (log.contains('ESP32:')) {
                        logColor = Colors.amber;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: logColor,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(UsbDiagnosticState state) {
    switch (state) {
      case UsbDiagnosticState.noDevice:
        return Colors.red;
      case UsbDiagnosticState.deviceFound:
        return Colors.orange;
      case UsbDiagnosticState.connectedNoData:
        return Colors.yellow;
      case UsbDiagnosticState.connectedReceiving:
        return Colors.lightBlue;
      case UsbDiagnosticState.fullyOperational:
        return Colors.green;
    }
  }

  IconData _getStateIcon(UsbDiagnosticState state) {
    switch (state) {
      case UsbDiagnosticState.noDevice:
        return Icons.usb_off;
      case UsbDiagnosticState.deviceFound:
        return Icons.usb;
      case UsbDiagnosticState.connectedNoData:
        return Icons.sync_problem;
      case UsbDiagnosticState.connectedReceiving:
        return Icons.sync;
      case UsbDiagnosticState.fullyOperational:
        return Icons.check_circle;
    }
  }

  String _getStateTitle(UsbDiagnosticState state) {
    switch (state) {
      case UsbDiagnosticState.noDevice:
        return 'Sin dispositivo USB';
      case UsbDiagnosticState.deviceFound:
        return 'Dispositivo detectado';
      case UsbDiagnosticState.connectedNoData:
        return 'Conectado - Sin datos';
      case UsbDiagnosticState.connectedReceiving:
        return 'Recibiendo datos';
      case UsbDiagnosticState.fullyOperational:
        return '✓ Operativo';
    }
  }

  String _getCompactStatusText(UsbDiagnosticInfo info) {
    switch (info.state) {
      case UsbDiagnosticState.noDevice:
        return 'USB: Desconectado';
      case UsbDiagnosticState.deviceFound:
        return 'USB: Encontrado';
      case UsbDiagnosticState.connectedNoData:
        return 'USB: Sin datos';
      case UsbDiagnosticState.connectedReceiving:
        return 'USB: Recibiendo...';
      case UsbDiagnosticState.fullyOperational:
        return 'USB: OK ✓';
    }
  }

  String? _getTroubleshootingHint(UsbDiagnosticInfo info) {
    switch (info.state) {
      case UsbDiagnosticState.noDevice:
        return '1. Verifica que el cable USB está conectado\n'
               '2. Revisa que el ESP32 está encendido\n'
               '3. El cable debe ser de DATOS (no solo carga)';
      
      case UsbDiagnosticState.deviceFound:
        return 'Dispositivo detectado pero no conectado.\n'
               'Espera unos segundos o toca para forzar conexión.';
      
      case UsbDiagnosticState.connectedNoData:
        final elapsed = info.timeSinceLastData;
        if (elapsed == null || elapsed.inSeconds > 10) {
          return '⚠️ Conectado pero sin recibir datos:\n'
                 '1. Verifica que el ESP32 está ejecutando el firmware correcto\n'
                 '2. Revisa que los botones RS-485 están conectados\n'
                 '3. Abre el Monitor Serie de Arduino para verificar';
        }
        return null;
      
      case UsbDiagnosticState.connectedReceiving:
        if (info.packetsWithErrors > 0) {
          return '⚠️ FORMATO INCORRECTO:\n'
                 '- Los datos llegan pero NO son P_A, P_B, etc.\n'
                 '- Revisa el LOG para ver qué envía el ESP32\n'
                 '- Posible firmware diferente al esperado';
        }
        return 'Recibiendo datos del ESP32.\n'
               'Presiona un botón para ver si llegan comandos.';
      
      case UsbDiagnosticState.fullyOperational:
        if (info.lastCommand != null) {
          return '✓ Último comando: ${info.lastCommand}';
        }
        return null;
    }
  }
}

/// Widget minimalista que solo muestra un indicador de estado
/// Para usar en la esquina de la pantalla sin ser invasivo
class UsbStatusIndicator extends StatelessWidget {
  final ValueNotifier<UsbDiagnosticInfo> diagnosticNotifier;
  final VoidCallback? onTap;

  const UsbStatusIndicator({
    super.key,
    required this.diagnosticNotifier,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UsbDiagnosticInfo>(
      valueListenable: diagnosticNotifier,
      builder: (context, info, _) {
        final color = _getStateColor(info.state);
        final isActive = info.isReceivingData;
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador LED
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: color.withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.usb, color: color, size: 16),
                if (info.commandsReceived > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${info.commandsReceived}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStateColor(UsbDiagnosticState state) {
    switch (state) {
      case UsbDiagnosticState.noDevice:
        return Colors.red;
      case UsbDiagnosticState.deviceFound:
        return Colors.orange;
      case UsbDiagnosticState.connectedNoData:
        return Colors.yellow;
      case UsbDiagnosticState.connectedReceiving:
        return Colors.lightBlue;
      case UsbDiagnosticState.fullyOperational:
        return Colors.green;
    }
  }
}
