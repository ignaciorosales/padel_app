import 'package:flutter/foundation.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';

/// Capa de aplicación que traduce los comandos YA validados en eventos del
/// [ScoringBloc].
///
/// Arquitectura por capas:
///  1. Transporte / parsing (NO MODIFICAR): `SimpleUsbSerialListener` lee el
///     puerto serie, filtra ruido y emite cadenas de comando validadas
///     (`P_A`, `P_B`, `UNDO_A`, `UNDO_B`, `RESET`, `PONG`). Esa capa funciona
///     con el hardware y no debe tocarse.
///  2. Lógica de la app (ESTA CLASE, modificable): decide qué hace cada
///     comando dentro del partido (mapeo de lados, swap, reinicio...).
///
/// Tanto el hardware USB real como la herramienta de testing dentro de la app
/// pasan por [handle], de modo que probar con la herramienta ejercita
/// EXACTAMENTE el mismo flujo que la botonera física.
class HardwareCommandHandler {
  HardwareCommandHandler({
    required this.bloc,
    required this.pairing,
  });

  final ScoringBloc bloc;

  /// Empareja cada caja física (por su ID) con un equipo. El hardware envía
  /// `BTN:<idHex>:<P|U|G>` y aquí se resuelve el equipo correspondiente.
  final BoxPairingService pairing;

  /// `true` cuando se recibió un RESET y se está esperando la confirmación
  /// por hardware. La UI escucha este valor para mostrar las instrucciones
  /// en pantalla (verde/sensor = reiniciar, blanco/rojo = cancelar).
  final ValueNotifier<bool> pendingReset = ValueNotifier<bool>(false);

  // Comandos soportados por el hardware. Deben coincidir con los que emite
  // la capa de transporte (`SimpleUsbSerialListener`).
  static const String pointLeft = 'P_A';
  static const String pointRight = 'P_B';
  static const String undoLeft = 'UNDO_A';
  static const String undoRight = 'UNDO_B';
  static const String reset = 'RESET';
  static const String resetGame = 'RESET_GAME';
  static const String pong = 'PONG';

  /// Procesa un comando (venga del hardware o del overlay de testing).
  void handle(String rawCommand) {
    final cmd = rawCommand.trim().toUpperCase();
    if (cmd.isEmpty) return;

    // Nuevo protocolo por caja: BTN:<idHex>:<P|U|G>. La app decide el equipo.
    if (cmd.startsWith('BTN:')) {
      _handleBoxCommand(cmd);
      return;
    }

    // Si hay un reinicio esperando confirmación, este comando lo resuelve
    // en lugar de aplicarse al marcador.
    if (pendingReset.value) {
      _resolvePendingReset(cmd);
      return;
    }

    // P_A = botonera IZQUIERDA física, P_B = botonera DERECHA física.
    // El estado de swap determina qué equipo está en cada lado.
    final isSwapped = bloc.state.isSwapped;
    final leftTeam = isSwapped ? Team.red : Team.blue;
    final rightTeam = isSwapped ? Team.blue : Team.red;

    switch (cmd) {
      case pointLeft:
        bloc.add(ScoringEvent.pointFor(leftTeam));
      case pointRight:
        bloc.add(ScoringEvent.pointFor(rightTeam));
      case undoLeft:
        bloc.add(ScoringEvent.undoForTeam(leftTeam));
      case undoRight:
        bloc.add(ScoringEvent.undoForTeam(rightTeam));
      case reset:
      case resetGame:
        // No reiniciamos directamente: entramos en modo "pendiente" y
        // esperamos que el árbitro confirme con un botón/sensor de PUNTO.
        pendingReset.value = true;
      case pong:
        break;
    }
  }

  /// Procesa un comando basado en el ID de la caja: `BTN:<idHex>:<P|U|G>`.
  ///
  /// A diferencia del flujo por lados (P_A/P_B), aquí la caja está emparejada
  /// directamente con un EQUIPO, así que el punto va siempre a ese equipo
  /// independientemente del swap (el swap solo afecta a la visualización).
  void _handleBoxCommand(String cmd) {
    final parts = cmd.split(':');
    if (parts.length != 3) return;
    final boxId = parts[1];
    final letter = parts[2];

    // Confirmación de reinicio pendiente: un PUNTO confirma, lo demás cancela.
    if (pendingReset.value) {
      if (letter == 'P') {
        performReset();
      } else {
        cancelReset();
      }
      return;
    }

    final team = pairing.teamForBox(boxId);
    if (team == null) {
      // Caja sin emparejar: se registra para poder asignarla en Ajustes.
      pairing.reportUnpairedBox(boxId);
      return;
    }

    switch (letter) {
      case 'P':
        bloc.add(ScoringEvent.pointFor(team));
      case 'U':
        bloc.add(ScoringEvent.undoForTeam(team));
      case 'G':
        // Igual que RESET: entra en modo pendiente y espera confirmación.
        pendingReset.value = true;
    }
  }

  /// Decide el resultado de un reinicio pendiente según el comando recibido:
  ///  - PUNTO (botón/sensor verde) => confirma y reinicia.
  ///  - PONG (latido del hardware) => se ignora, sigue pendiente.
  ///  - Cualquier otro (UNDO, RESET...) => cancela.
  void _resolvePendingReset(String cmd) {
    switch (cmd) {
      case pointLeft:
      case pointRight:
        performReset();
      case pong:
        // Latido periódico: no debe cancelar la confirmación.
        break;
      default:
        cancelReset();
    }
  }

  /// Ejecuta el reinicio real del partido. Debe llamarse tras confirmar.
  void performReset() {
    pendingReset.value = false;
    bloc.add(const ScoringEvent.resetSwap());
    bloc.add(const ScoringEvent.newMatch());
  }

  /// Cancela un reinicio pendiente sin tocar el marcador.
  void cancelReset() {
    pendingReset.value = false;
  }

  void dispose() {
    pendingReset.dispose();
  }
}
