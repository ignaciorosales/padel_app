import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/usb_serial/hardware_health.dart';

/// Pantalla de diagnóstico del hardware.
///
/// Pensada para la INSTALACIÓN en pista: responde de un vistazo a "¿está el
/// maestro conectado?", "¿responden las 4 cajas?" y, cuando algo falla, "¿qué
/// tengo que tocar?". Los tres fallos de la cadena (USB / maestro / bus
/// RS-485) se ven idénticos desde fuera, así que aquí se separan
/// explícitamente.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.monitor});

  final HardwareHealthMonitor monitor;

  static Future<void> open(
    BuildContext context,
    HardwareHealthMonitor monitor,
  ) {
    final pairing = context.read<BoxPairingService>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: pairing,
          child: DiagnosticsScreen(monitor: monitor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairing = context.read<BoxPairingService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: monitor,
          builder: (context, _) {
            return ValueListenableBuilder<Map<String, int>>(
              valueListenable: pairing.pairings,
              builder: (context, pairings, __) {
                final pairedIds = pairings.entries
                    .where((e) => e.value != BoxPairingService.unassigned)
                    .map((e) => e.key)
                    .toSet();
                final issues = monitor.issues(pairedBoxIds: pairedIds);

                return Column(
                  children: [
                    _Header(monitor: monitor, issues: issues),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ChainCard(monitor: monitor),
                                  const SizedBox(height: 12),
                                  _MasterCard(monitor: monitor),
                                  const SizedBox(height: 12),
                                  _LogCard(monitor: monitor),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _BoxesCard(
                                    monitor: monitor,
                                    pairings: pairings,
                                  ),
                                  const SizedBox(height: 12),
                                  _IssuesCard(issues: issues),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================================
// Cabecera
// ===========================================================================

class _Header extends StatelessWidget {
  const _Header({required this.monitor, required this.issues});

  final HardwareHealthMonitor monitor;
  final List<HealthIssue> issues;

  @override
  Widget build(BuildContext context) {
    final critical = issues.where((i) => i.level == IssueLevel.critical).length;
    final warnings = issues.where((i) => i.level == IssueLevel.warning).length;

    final Color color;
    final IconData icon;
    if (critical > 0) {
      color = const Color(0xFFE74C3C);
      icon = Icons.error;
    } else if (warnings > 0) {
      color = const Color(0xFFF39C12);
      icon = Icons.warning_amber_rounded;
    } else {
      color = const Color(0xFF2ECC71);
      icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            tooltip: 'Volver',
          ),
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DIAGNÓSTICO DEL SISTEMA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  monitor.summary,
                  style: TextStyle(color: color, fontSize: 15),
                ),
              ],
            ),
          ),
          _ActionButton(
            label: 'Actualizar',
            icon: Icons.refresh,
            onTap: monitor.requestStatus,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: monitor.buttonTestMode
                ? 'Salir de prueba'
                : 'Probar botones',
            icon: Icons.touch_app,
            highlighted: monitor.buttonTestMode,
            onTap: () => monitor.setButtonTestMode(!monitor.buttonTestMode),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color =
        highlighted ? const Color(0xFFF39C12) : const Color(0xFF42A5F5);
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ===========================================================================
// Tarjeta base
// ===========================================================================

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17171F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ===========================================================================
// Cadena de conexión: USB -> maestro -> cajas
// ===========================================================================

class _ChainCard extends StatelessWidget {
  const _ChainCard({required this.monitor});

  final HardwareHealthMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final stage = monitor.stage;

    // Cada eslabón: ok / fallando / pendiente.
    final usbOk = monitor.usbConnected;
    final masterOk = usbOk && monitor.masterAlive && monitor.hasTelemetry;
    final master = monitor.master;
    final boxesOk = masterOk && master != null && master.onlineCount > 0;
    final allBoxesOk =
        masterOk && master != null && master.onlineCount == master.slaveCount;

    return _Card(
      title: 'Cadena de conexión',
      child: Column(
        children: [
          _ChainStep(
            index: 1,
            label: 'Cable USB',
            detail: usbOk
                ? 'Puerto abierto · ${monitor.usbDeviceName ?? 'dispositivo'}'
                : stage == UsbStage.deviceNotOpened
                    ? '${monitor.usbDevicesFound} dispositivo(s) vistos, no abre'
                    : 'Sin dispositivo USB',
            ok: usbOk,
          ),
          _ChainStep(
            index: 2,
            label: 'Maestro ESP32',
            detail: !usbOk
                ? 'A la espera del USB'
                : !monitor.masterAlive
                    ? 'No responde'
                    : !monitor.hasTelemetry
                        ? 'Responde, pero sin telemetría (firmware antiguo)'
                        : 'Activo · firmware v${master?.fwVersion ?? '?'}',
            ok: masterOk,
            pending: !usbOk,
          ),
          _ChainStep(
            index: 3,
            label: 'Bus RS-485 y cajas',
            detail: !masterOk
                ? 'A la espera del maestro'
                : master == null
                    ? 'Sin datos'
                    : '${master.onlineCount} de ${master.slaveCount} cajas responden',
            ok: allBoxesOk,
            partial: boxesOk && !allBoxesOk,
            pending: !masterOk,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ChainStep extends StatelessWidget {
  const _ChainStep({
    required this.index,
    required this.label,
    required this.detail,
    required this.ok,
    this.partial = false,
    this.pending = false,
    this.isLast = false,
  });

  final int index;
  final String label;
  final String detail;
  final bool ok;
  final bool partial;
  final bool pending;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    if (pending) {
      color = Colors.white24;
      icon = Icons.remove_circle_outline;
    } else if (ok) {
      color = const Color(0xFF2ECC71);
      icon = Icons.check_circle;
    } else if (partial) {
      color = const Color(0xFFF39C12);
      icon = Icons.warning_amber_rounded;
    } else {
      color = const Color(0xFFE74C3C);
      icon = Icons.cancel;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 22),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: color.withValues(alpha: .35)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. $label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Datos del maestro
// ===========================================================================

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.monitor});

  final HardwareHealthMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final m = monitor.master;
    if (m == null) {
      return const _Card(
        title: 'Maestro',
        child: Text(
          'Sin telemetría del maestro todavía.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final uptime = Duration(milliseconds: m.uptimeMs);
    return _Card(
      title: 'Maestro',
      child: Column(
        children: [
          _kv('Firmware', 'v${m.fwVersion}'),
          _kv('En marcha desde hace', _fmtDuration(uptime)),
          _kv('Ciclo de poleo', '${m.cycleMs} ms'),
          _kv('RS-485', '${m.rs485Baud} baudios'),
          _kv('USB', '${m.usbBaud} baudios'),
          _kv('Polls totales', '${m.polls}'),
          _kv('Tramas / bytes', '${m.frames} / ${m.rxBytes}'),
          _kv('Errores CRC', '${m.crcErrors}',
              warn: m.crcErrors > 0),
          _kv('ID inesperado', '${m.wrongId}', warn: m.wrongId > 0),
        ],
      ),
    );
  }

  static Widget _kv(String k, String v, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Text(
            v,
            style: TextStyle(
              color: warn ? const Color(0xFFF39C12) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }
}

// ===========================================================================
// Las 4 cajas
// ===========================================================================

class _BoxesCard extends StatelessWidget {
  const _BoxesCard({required this.monitor, required this.pairings});

  final HardwareHealthMonitor monitor;
  final Map<String, int> pairings;

  @override
  Widget build(BuildContext context) {
    final boxes = monitor.boxes.isEmpty
        ? kDefaultBoxIds.map((id) => BoxHealth(id: id)).toList()
        : monitor.boxes;

    return _Card(
      title: 'Cajas de botones',
      trailing: monitor.buttonTestMode
          ? TextButton.icon(
              onPressed: monitor.resetButtonTest,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reiniciar prueba'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF39C12),
              ),
            )
          : null,
      child: Column(
        children: [
          if (monitor.buttonTestMode)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF39C12)),
              ),
              child: const Text(
                'MODO PRUEBA ACTIVO — las pulsaciones NO puntúan. '
                'Pulsa los 3 botones de cada caja para verificarlos.',
                style: TextStyle(color: Color(0xFFF39C12), fontSize: 13),
              ),
            ),
          ...boxes.map(
            (b) => _BoxRow(
              box: b,
              teamIndex: pairings[b.id],
              buttonsSeen: monitor.buttonsSeenFor(b.id),
              showButtons: monitor.buttonTestMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({
    required this.box,
    required this.teamIndex,
    required this.buttonsSeen,
    required this.showButtons,
  });

  final BoxHealth box;
  final int? teamIndex;
  final Set<String> buttonsSeen;
  final bool showButtons;

  @override
  Widget build(BuildContext context) {
    final color = box.online
        ? const Color(0xFF2ECC71)
        : box.neverSeen
            ? const Color(0xFFE74C3C)
            : const Color(0xFFF39C12);

    final String teamLabel;
    final Color teamColor;
    if (teamIndex == 1) {
      teamLabel = 'Equipo 1';
      teamColor = const Color(0xFF42A5F5);
    } else if (teamIndex == 2) {
      teamLabel = 'Equipo 2';
      teamColor = const Color(0xFFE74C3C);
    } else {
      teamLabel = 'Sin equipo';
      teamColor = Colors.white38;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                box.id.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: teamColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  teamLabel,
                  style: TextStyle(color: teamColor, fontSize: 11),
                ),
              ),
              const Spacer(),
              Text(
                box.online
                    ? 'CONECTADA'
                    : box.neverSeen
                        ? 'NUNCA VISTA'
                        : 'SIN RESPUESTA',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _stat('RTT', box.online ? '${box.lastRttMs} ms' : '—'),
              _stat('Respuestas', '${box.replies}'),
              _stat('Timeouts', '${box.timeouts}',
                  warn: box.timeouts > 0 && box.lossRatio > 0.1),
              _stat('CRC', '${box.crcErrors}', warn: box.crcErrors > 0),
              _stat('Pulsaciones', '${box.commands}'),
            ],
          ),
          if (showButtons) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Botones: ',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                ...['P', 'U', 'G'].map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ButtonChip(
                      label: k,
                      seen: buttonsSeen.contains(k),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _stat(String label, String value, {bool warn = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              color: warn ? const Color(0xFFF39C12) : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonChip extends StatelessWidget {
  const _ButtonChip({required this.label, required this.seen});

  final String label;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final color = seen ? const Color(0xFF2ECC71) : Colors.white24;
    return Container(
      width: 30,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: seen ? const Color(0xFF2ECC71) : Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ===========================================================================
// Problemas detectados
// ===========================================================================

class _IssuesCard extends StatelessWidget {
  const _IssuesCard({required this.issues});

  final List<HealthIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const _Card(
        title: 'Problemas detectados',
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Todo correcto. Maestro y cajas responden con normalidad.',
                style: TextStyle(color: Color(0xFF2ECC71), fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return _Card(
      title: 'Problemas detectados (${issues.length})',
      child: Column(children: issues.map((i) => _IssueTile(issue: i)).toList()),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final HealthIssue issue;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (issue.level) {
      IssueLevel.critical => (const Color(0xFFE74C3C), Icons.error),
      IssueLevel.warning => (
          const Color(0xFFF39C12),
          Icons.warning_amber_rounded
        ),
      IssueLevel.info => (const Color(0xFF42A5F5), Icons.info_outline),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  issue.detail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (issue.action != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.build_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issue.action!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Log crudo
// ===========================================================================

class _LogCard extends StatelessWidget {
  const _LogCard({required this.monitor});

  final HardwareHealthMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final logs = monitor.logs.reversed.take(40).toList();
    return _Card(
      title: 'Log del puerto serie',
      child: SizedBox(
        height: 180,
        child: logs.isEmpty
            ? const Center(
                child: Text(
                  'Sin líneas recibidas.',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              )
            : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    logs[i],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
