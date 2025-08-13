import 'package:freezed_annotation/freezed_annotation.dart';

part 'scoring_models.freezed.dart';
part 'scoring_models.g.dart';

enum Team { blue, red }

@freezed
class MatchSettings with _$MatchSettings {
  const factory MatchSettings({
    @Default(true) bool goldenPoint,
    @Default(true) bool tieBreakAtSixSix,
    @Default(7) int tieBreakTarget,
    @Default(2) int setsToWin,
  }) = MatchSettingsImpl;

  factory MatchSettings.fromJson(Map<String, dynamic> json) =>
      _$MatchSettingsFromJson(json);
}

@freezed
class GamePoints with _$GamePoints {
  const factory GamePoints({
    @Default(0) int blue,
    @Default(0) int red,
    @Default(false) bool isTieBreak,
  }) = GamePointsImpl;

  factory GamePoints.fromJson(Map<String, dynamic> json) =>
      _$GamePointsFromJson(json);
}

@freezed
class SetScore with _$SetScore {
  const factory SetScore({
    @Default(0) int blueGames,
    @Default(0) int redGames,
    @Default(GamePoints()) GamePoints currentGame,
    Team? tieBreakStarter, // 👈 THIS FIELD MUST EXIST
  }) = SetScoreImpl;

  factory SetScore.fromJson(Map<String, dynamic> json) =>
      _$SetScoreFromJson(json);
}

@freezed
class MatchScore with _$MatchScore {
  const factory MatchScore({
    @Default(<SetScore>[]) List<SetScore> sets,
    @Default(0) int currentSetIndex,
    @Default(Team.blue) Team server,
    @Default(Team.red) Team receiver,
    @Default('Azul') String blueName,
    @Default('Rojo') String redName,
    @Default(false) bool paused,
    @Default(MatchSettings()) MatchSettings settings,
  }) = MatchScoreImpl;

  const MatchScore._();

  SetScore get currentSet =>
      sets.isEmpty ? const SetScore() : sets[currentSetIndex];

  factory MatchScore.fromJson(Map<String, dynamic> json) =>
      _$MatchScoreFromJson(json);
}
