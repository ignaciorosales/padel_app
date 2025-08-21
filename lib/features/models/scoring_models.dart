import 'package:freezed_annotation/freezed_annotation.dart';
part 'scoring_models.freezed.dart';
part 'scoring_models.g.dart';

enum Team { blue, red }

@freezed
class MatchSettings with _$MatchSettings {
  const factory MatchSettings({
    @Default(2) int setsToWin,
    /// 6 (clásico) o 12 (super set)
    @Default(6) int tieBreakAtGames,
    /// En deuce el siguiente punto decide
    @Default(false) bool goldenPoint,
    /// Objetivo del TB (p.ej. 7 o 10, siempre con diferencia de 2)
    @Default(7) int tieBreakTarget,
  }) = _MatchSettings;

  factory MatchSettings.fromJson(Map<String, dynamic> json) =>
      _$MatchSettingsFromJson(json);
}

@freezed
class GamePoints with _$GamePoints {
  const factory GamePoints({
    @Default(0) int blue,
    @Default(0) int red,
    @Default(false) bool isTieBreak,
  }) = _GamePoints;

  factory GamePoints.fromJson(Map<String, dynamic> json) =>
      _$GamePointsFromJson(json);
}

@freezed
class SetScore with _$SetScore {
  const factory SetScore({
    @Default(0) int blueGames,
    @Default(0) int redGames,
    @Default(GamePoints()) GamePoints currentGame,
    /// Servidor que comenzó el tie-break (rotación 1–2–2–2)
    Team? tieBreakStarter,
  }) = _SetScore;

  factory SetScore.fromJson(Map<String, dynamic> json) =>
      _$SetScoreFromJson(json);
}

@freezed
class MatchScore with _$MatchScore {
  @JsonSerializable(explicitToJson: true) // necesario para nested toJson()
  const factory MatchScore({
    @Default(<SetScore>[]) List<SetScore> sets,
    @Default(0) int currentSetIndex,
    @Default(Team.blue) Team server,
    @Default(Team.red) Team receiver,
    @Default('Azul') String blueName,
    @Default('Rojo') String redName,
    @Default(false) bool paused,
    @Default(MatchSettings()) MatchSettings settings,
  }) = _MatchScore;

  const MatchScore._();

  SetScore get currentSet =>
      sets.isEmpty ? const SetScore() : sets[currentSetIndex];

  factory MatchScore.fromJson(Map<String, dynamic> json) =>
      _$MatchScoreFromJson(json);
}
