import 'package:flutter/material.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/usb_serial/hardware_health.dart';

/// Asistente a pantalla completa para decir en qué lado está cada caja.
///
/// Se maneja con las propias cajas: la pantalla pide "pulsa un botón de una
/// caja del lado izquierdo", la caja pulsada queda registrada en ese lado, y
/// así hasta completar los dos. No hace falta saber el ID de ninguna caja ni
/// el orden en que se encendieron. El mando de la TV solo se usa para saltar
/// un lado con menos cajas o cancelar.
class BoxSetupWizard extends StatefulWidget {
  const BoxSetupWizard({
    super.key,
    required this.pairing,
    required this.health,
  });

  final BoxPairingService pairing;
  final HardwareHealthMonitor health;

  @override
  State<BoxSetupWizard> createState() => _BoxSetupWizardState();
}

class _BoxSetupWizardState extends State<BoxSetupWizard> {
  static const _leftColor = Color(0xFF42A5F5);
  static const _rightColor = Color(0xFFFFA726);

  bool _closeScheduled = false;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.94),
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.pairing.setup, widget.health]),
          builder: (context, _) {
            final s = widget.pairing.setup.value;
            if (s == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: s.done ? _done(s) : _step(s),
            );
          },
        ),
      ),
    );
  }

  Widget _step(BoxSetup s) {
    final isLeft = s.side == BoxPairingService.left;
    final sideName = isLeft ? 'IZQUIERDO' : 'DERECHO';
    final color = isLeft ? _leftColor : _rightColor;
    final count = s.countOn(s.side);
    final online = widget.health.boxes.where((b) => b.online).length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Configurar cajas · paso ${s.side} de 2',
          style: const TextStyle(color: Colors.white54, fontSize: 20),
        ),
        const SizedBox(height: 24),
        _court(s),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 34),
            children: [
              TextSpan(
                text:
                    count == 0
                        ? 'Pulsa cualquier botón de una caja del lado '
                        : 'Ahora pulsa un botón de la OTRA caja del lado ',
              ),
              TextSpan(
                text: sideName,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'El lado $sideName es el que esta pantalla muestra a la '
          '${isLeft ? 'izquierda' : 'derecha'}.',
          style: const TextStyle(color: Colors.white60, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 32,
          child:
              s.repeated != null
                  ? Text(
                    'Esa caja ya está registrada. Pulsa otra caja.',
                    style: const TextStyle(color: Colors.amber, fontSize: 22),
                  )
                  : Text(
                    _busHint(online),
                    style: TextStyle(
                      color: online == 0 ? Colors.redAccent : Colors.white38,
                      fontSize: 18,
                    ),
                  ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: widget.pairing.nextSetupSide,
              child: Text(
                count == 0
                    ? 'Este lado no tiene cajas'
                    : 'Este lado no tiene más cajas',
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: widget.pairing.closeSetup,
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    );
  }

  /// Qué decir sobre el bus mientras se espera una pulsación: si ninguna
  /// caja responde, pulsar no va a hacer nada y hay que decirlo.
  String _busHint(int online) {
    if (!widget.health.usbConnected) {
      return 'El maestro no está conectado: las cajas no van a responder.';
    }
    if (!widget.health.hasTelemetry) return '';
    if (online == 0) {
      return 'Ninguna caja responde. Revisa el cable de las cajas.';
    }
    return '$online ${online == 1 ? 'caja conectada' : 'cajas conectadas'}';
  }

  Widget _done(BoxSetup s) {
    if (!_closeScheduled) {
      _closeScheduled = true;
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) widget.pairing.closeSetup();
      });
    }
    final total = s.captured.length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 72),
        const SizedBox(height: 16),
        Text(
          total == 0
              ? 'No se ha configurado ninguna caja'
              : '¡Listo! $total ${total == 1 ? 'caja configurada' : 'cajas configuradas'}',
          style: const TextStyle(color: Colors.white, fontSize: 36),
        ),
        const SizedBox(height: 24),
        _court(s),
        const SizedBox(height: 24),
        const Text(
          'Comprueba: al pulsar el punto en una caja, el punto debe aparecer '
          'en su lado de la pantalla.',
          style: TextStyle(color: Colors.white60, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          autofocus: true,
          onPressed: widget.pairing.closeSetup,
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  /// Pista vista desde la pantalla: dos mitades con un hueco por caja.
  Widget _court(BoxSetup s) {
    Widget half(int side, String label, Color color) {
      final active = s.side == side;
      final ids =
          s.captured.entries
              .where((e) => e.value == side)
              .map((e) => e.key.toUpperCase())
              .toList();
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 150,
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 0.22 : 0.06),
            border: Border.all(
              color: active ? color : Colors.white24,
              width: active ? 4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? color : Colors.white54,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < BoxPairingService.boxesPerSide; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _slot(i < ids.length ? ids[i] : null, color),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Row(
        children: [
          half(BoxPairingService.left, 'IZQUIERDA', _leftColor),
          // La red.
          Container(width: 6, height: 170, color: Colors.white70),
          half(BoxPairingService.right, 'DERECHA', _rightColor),
        ],
      ),
    );
  }

  Widget _slot(String? id, Color color) {
    final done = id != null;
    return Column(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? color : Colors.white30,
          size: 40,
        ),
        const SizedBox(height: 4),
        Text(
          id ?? 'caja',
          style: TextStyle(
            color: done ? Colors.white : Colors.white30,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
