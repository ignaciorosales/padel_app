import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
part 'scoring_event.freezed.dart';

@freezed
class ScoringEvent with _$ScoringEvent {
  const factory ScoringEvent.newMatch({
    MatchSettings? settings,
    Team? startingServer,
  }) = NewMatchEvent;

  const factory ScoringEvent.newSet() = NewSetEvent;
  const factory ScoringEvent.newGame() = NewGameEvent;

  const factory ScoringEvent.pointFor(Team team) = PointForEvent;
  const factory ScoringEvent.removePoint(Team team) = RemovePointEvent;

  const factory ScoringEvent.forceGameFor(Team team) = ForceGameForEvent;
  const factory ScoringEvent.forceSetFor(Team team) = ForceSetForEvent;

  const factory ScoringEvent.setExplicitGamePoints({
    required int blue,
    required int red,
  }) = SetExplicitGamePointsEvent;

  const factory ScoringEvent.toggleTieBreakGames(int games) = ToggleTieBreakGamesEvent;
  const factory ScoringEvent.toggleGoldenPoint(bool enabled) = ToggleGoldenPointEvent;

  const factory ScoringEvent.announceScore() = AnnounceScoreEvent;

  const factory ScoringEvent.undo() = UndoEvent;
  const factory ScoringEvent.redo() = RedoEvent;

  const factory ScoringEvent.undoForTeam(Team team) = UndoForTeamEvent;

  /// Raw BLE command from ESP32: 'a','b','u' etc.
  const factory ScoringEvent.bleCommand(String cmd) = BleCommandEvent;
}
