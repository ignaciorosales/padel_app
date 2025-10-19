import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:Puntazo/features/models/scoring_models.dart';

part 'command.freezed.dart';

@freezed
sealed class Command with _$Command {
  // Partido / set / juego
  const factory Command.newMatch() = _CmdNewMatch;
  const factory Command.newSet() = _CmdNewSet;
  const factory Command.newGame() = _CmdNewGame;

  // Puntos
  const factory Command.pointFor(Team team) = _CmdPointFor;
  const factory Command.removePoint(Team team) = _CmdRemovePoint;

  // Forzados / ajustes de marcador
  const factory Command.forceGameFor(Team team) = _CmdForceGameFor;
  const factory Command.forceSetFor(Team team) = _CmdForceSetFor;
  const factory Command.setExplicitGamePoints(int blue, int red) = _CmdSetPoints;

  // Reglas (configurables desde UI/voz)
  // const factory Command.toggleTieBreakAtSixSix(bool enabled) = _CmdToggleTieRule;
  const factory Command.toggleGoldenPoint(bool enabled) = _CmdToggleGoldenPoint;

  // Utilidades
  const factory Command.announceScore() = _CmdAnnounceScore;
  const factory Command.undo() = _CmdUndo;
  const factory Command.redo() = _CmdRedo;
}
