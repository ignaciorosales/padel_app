import 'package:freezed_annotation/freezed_annotation.dart';
part 'scoring_models.freezed.dart';
part 'scoring_models.g.dart';

/// Representa los dos equipos: verde y negro
enum Team { blue, red }

/// Configuración del partido de pádel
///
/// Los partidos de pádel estándar tienen las siguientes reglas:
/// - Partido al mejor de 3 sets (2 sets para ganar)
/// - Juegos con punto de oro opcional en 40-40 (deuce)
/// - Tie-break a 7 puntos en 6-6 en cada set (con diferencia de 2)
/// - Tercer set: puede ser un set completo o un Super Tie-Break a 10 puntos
@freezed
class MatchSettings with _$MatchSettings {
  const factory MatchSettings({
    /// Número de sets para ganar el partido (normalmente 2)
    @Default(2) int setsToWin,
    
    /// Juegos para llegar al tie-break:
    /// - 6: Tie-break normal a 7 puntos cuando se llega a 6-6 en games
    /// - 1: Super Tie-Break a 10 puntos en el tercer set (en lugar de jugar un set completo)
    @Default(6) int tieBreakAtGames,
    
    /// Punto de oro en 40-40 (deuce)
    /// - true: En 40-40, el siguiente punto decide el juego (punto de oro)
    /// - false: En 40-40, hay que ganar por diferencia de 2 puntos (ventaja/desventaja)
    @Default(false) bool goldenPoint,
    
    /// Puntos objetivo para ganar un tie-break (siempre con diferencia de 2):
    /// - 7: Para tie-breaks normales en 6-6
    /// - 10: Para Super Tie-Break en el tercer set
    @Default(7) int tieBreakTarget,
  }) = _MatchSettings;

  factory MatchSettings.fromJson(Map<String, dynamic> json) =>
      _$MatchSettingsFromJson(json);
}

/// Representa los puntos dentro de un juego (game) o tie-break
@freezed
class GamePoints with _$GamePoints {
  const factory GamePoints({
    /// Puntos del equipo verde en el juego actual
    @Default(0) int blue,
    
    /// Puntos del equipo negro en el juego actual
    @Default(0) int red,
    
    /// Indica si el juego actual es un tie-break
    /// - true: Conteo 1,2,3,... hasta llegar al objetivo (7 o 10)
    /// - false: Conteo 0,15,30,40,AD en juegos normales
    @Default(false) bool isTieBreak,
  }) = _GamePoints;

  factory GamePoints.fromJson(Map<String, dynamic> json) =>
      _$GamePointsFromJson(json);
}

/// Representa la puntuación de un set completo
@freezed
class SetScore with _$SetScore {
  const factory SetScore({
    /// Juegos ganados por el equipo verde en este set
    @Default(0) int blueGames,
    
    /// Juegos ganados por el equipo negro en este set
    @Default(0) int redGames,
    
    /// Puntos del juego actual dentro del set
    @Default(GamePoints()) GamePoints currentGame,
    
    /// Servidor que comenzó el tie-break (para la rotación 1–2–2–2)
    /// En tie-breaks, el servicio rota después de cada punto impar
    Team? tieBreakStarter,
    
    /// Indica si este set es un Super Tie-Break (a 10 puntos)
    /// - true: Es un Super Tie-Break (tercer set en formato 1)
    /// - false: Es un set normal (con tie-break regular a 7 puntos)
    @Default(false) bool isSuperTieBreak,
  }) = _SetScore;

  factory SetScore.fromJson(Map<String, dynamic> json) =>
      _$SetScoreFromJson(json);
}

/// Representa la puntuación completa del partido
@freezed
class MatchScore with _$MatchScore {
  @JsonSerializable(explicitToJson: true) // necesario para nested toJson()
  const factory MatchScore({
    /// Lista de todos los sets del partido
    @Default(<SetScore>[]) List<SetScore> sets,
    
    /// Índice del set actual (0 = primer set, 1 = segundo set, 2 = tercer set)
    @Default(0) int currentSetIndex,
    
    /// Equipo que tiene el servicio actualmente
    @Default(Team.blue) Team server,
    
    /// Equipo que recibe actualmente
    @Default(Team.red) Team receiver,
    
    /// Nombre del equipo verde
    @Default('Verde') String blueName,
    
    /// Nombre del equipo negro
    @Default('Negro') String redName,
    
    /// Indica si el partido está en pausa
    @Default(false) bool paused,
    
    /// Configuración del partido
    @Default(MatchSettings()) MatchSettings settings,
  }) = _MatchScore;

  const MatchScore._();

  /// Acceso rápido al set actual
  SetScore get currentSet =>
      sets.isEmpty ? const SetScore() : sets[currentSetIndex];

  factory MatchScore.fromJson(Map<String, dynamic> json) =>
      _$MatchScoreFromJson(json);
}
