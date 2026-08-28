import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// Overlay de testing que simula la botonera física desde dentro de la app.
///
/// Emite exactamente los mismos comandos que el hardware y los envía a través
/// de [HardwareCommandHandler]. De este modo, probar con esta herramienta
/// ejercita el mismo flujo (mapeo de lados, swap, reinicio con confirmación)
/// que la botonera USB real.
class TestingOverlay extends StatelessWidget {
  const TestingOverlay({super.key, required this.commandHandler});

  final HardwareCommandHandler commandHandler;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScoringBloc, ScoringState>(
      builder: (context, scoringState) {
        final teamService =
            RepositoryProvider.of<TeamSelectionService>(context);
        final isSwapped = scoringState.isSwapped;
        final leftColor =
            isSwapped ? teamService.getColor2() : teamService.getColor1();
        final rightColor =
            isSwapped ? teamService.getColor1() : teamService.getColor2();
        final match = scoringState.match;
        final currentServer = match.currentServer;
        final serverPos =
            currentServer.position == PlayerPosition.drive ? 'DRY' : 'REV';
        final serverTeam = currentServer.team == Team.blue ? 'Eq1' : 'Eq2';
        final settings = match.settings;
        final modeLabel = settings.matchMode == MatchMode.championship
            ? 'CAMPEONATO'
            : 'AMATEUR';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info del modo y servidor
              Text(
                'Modo: $modeLabel | Saque: $serverTeam $serverPos',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Botones que emiten los comandos reales del hardware
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TestingButton(
                    label: '+1',
                    color: leftColor,
                    onTap: () =>
                        commandHandler.handle(HardwareCommandHandler.pointLeft),
                  ),
                  const SizedBox(width: 8),
                  _TestingButton(
                    label: '+1',
                    color: rightColor,
                    onTap: () => commandHandler
                        .handle(HardwareCommandHandler.pointRight),
                  ),
                  const SizedBox(width: 16),
                  // Deshacer por equipo: UNDO_A = lado izquierdo, UNDO_B = derecho.
                  // Solo deshace si el último punto fue de ese lado (igual que el
                  // hardware), por eso se ofrece un botón por cada lado.
                  _TestingButton(
                    label: 'UNDO ◄',
                    color: leftColor,
                    onTap: () =>
                        commandHandler.handle(HardwareCommandHandler.undoLeft),
                  ),
                  const SizedBox(width: 8),
                  _TestingButton(
                    label: 'UNDO ►',
                    color: rightColor,
                    onTap: () =>
                        commandHandler.handle(HardwareCommandHandler.undoRight),
                  ),
                  const SizedBox(width: 16),
                  _TestingButton(
                    label: 'RESET',
                    color: Colors.red.shade700,
                    onTap: () =>
                        commandHandler.handle(HardwareCommandHandler.reset),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Info del set actual
              Text(
                'Set ${match.currentSetIndex + 1} | Games: ${match.currentSet.blueGames}-${match.currentSet.redGames} | Pts: ${match.currentSet.currentGame.blue}-${match.currentSet.currentGame.red}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              if (match.currentSet.currentGame.isTieBreak)
                Text(
                  match.currentSet.isSuperTieBreak
                      ? 'SUPER TIE-BREAK (a 11)'
                      : 'TIE-BREAK (a 7)',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Botón de testing para simular comandos manualmente.
class _TestingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TestingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
