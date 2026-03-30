import 'package:freezed_annotation/freezed_annotation.dart';
part 'scoring_models.freezed.dart';
part 'scoring_models.g.dart';

/// Representa los dos equipos: verde y negro
enum Team { blue, red }

/// Modo de partido: Amateur (reglas flexibles) o Campeonato (reglas oficiales)
enum MatchMode { 
  /// Modo Amateur: Sets 5-5 se deciden con diferencia de 2, máximo 9-8
  amateur, 
  /// Modo Campeonato: Sets 5-5 → tie break a 7, empate 1-1 → Super tie break a 11
  championship 
}

/// Posición del jugador en la pareja (para identificar quién saca)
enum PlayerPosition {
  /// Jugador de drive (DRY) - normalmente derecha de la pista
  drive,
  /// Jugador de revés - normalmente izquierda de la pista  
  backhand
}

/// Identificador completo del servidor actual (equipo + posición)
@freezed
class Server with _$Server {
  const factory Server({
    /// Equipo que tiene el servicio
    @Default(Team.blue) Team team,
    /// Posición del jugador que saca (drive o revés)
    @Default(PlayerPosition.drive) PlayerPosition position,
  }) = _Server;
  
  const Server._();
  
  /// Retorna el siguiente servidor en la rotación:
  /// DRY1 → DRY2 → REVÉS1 → REVÉS2 → DRY1...
  Server next() {
    // Rotación: drive blue → drive red → backhand blue → backhand red
    if (team == Team.blue && position == PlayerPosition.drive) {
      return const Server(team: Team.red, position: PlayerPosition.drive);
    } else if (team == Team.red && position == PlayerPosition.drive) {
      return const Server(team: Team.blue, position: PlayerPosition.backhand);
    } else if (team == Team.blue && position == PlayerPosition.backhand) {
      return const Server(team: Team.red, position: PlayerPosition.backhand);
    } else {
      return const Server(team: Team.blue, position: PlayerPosition.drive);
    }
  }
  
  /// Retorna el índice del servidor (0-3) para la rotación
  int get index {
    if (team == Team.blue && position == PlayerPosition.drive) return 0;
    if (team == Team.red && position == PlayerPosition.drive) return 1;
    if (team == Team.blue && position == PlayerPosition.backhand) return 2;
    return 3; // red + backhand
  }
  
  /// Crea un servidor a partir del índice (0-3)
  factory Server.fromIndex(int index) {
    switch (index % 4) {
      case 0: return const Server(team: Team.blue, position: PlayerPosition.drive);
      case 1: return const Server(team: Team.red, position: PlayerPosition.drive);
      case 2: return const Server(team: Team.blue, position: PlayerPosition.backhand);
      default: return const Server(team: Team.red, position: PlayerPosition.backhand);
    }
  }

  factory Server.fromJson(Map<String, dynamic> json) =>
      _$ServerFromJson(json);
}

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
    
    /// Modo de partido: Amateur o Campeonato
    /// - Amateur: Sets 5-5 se deciden con diferencia de 2, máximo 9-8
    /// - Campeonato: Sets 5-5 → tie break a 7, empate 1-1 → Super tie break a 11
    @Default(MatchMode.amateur) MatchMode matchMode,
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
    /// En tie-breaks, el servicio rota después de cada punto
    Server? tieBreakStartServer,
    
    /// @deprecated Mantener por compatibilidad con Team
    Team? tieBreakStarter,
    
    /// Indica si este set es un Super Tie-Break (a 10/11 puntos)
    /// - true: Es un Super Tie-Break (tercer set en formato campeonato o tradicional)
    /// - false: Es un set normal (con tie-break regular a 7 puntos)
    @Default(false) bool isSuperTieBreak,
  }) = _SetScore;

  factory SetScore.fromJson(Map<String, dynamic> json) =>
      _$SetScoreFromJson(json);
}

/// Representa la puntuación completa del partido
@freezed
class MatchScore with _$MatchScore {
  const factory MatchScore({
    /// Lista de todos los sets del partido
    @Default(<SetScore>[]) List<SetScore> sets,
    
    /// Índice del set actual (0 = primer set, 1 = segundo set, 2 = tercer set)
    @Default(0) int currentSetIndex,
    
    /// Servidor actual: equipo + posición (drive/revés)
    /// Rotación: DRY1 → DRY2 → REVÉS1 → REVÉS2 → repite
    @Default(Server()) Server currentServer,
    
    /// @deprecated Mantener por compatibilidad - usar currentServer.team
    @Default(Team.blue) Team server,
    
    /// @deprecated Mantener por compatibilidad
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

  /// Equipo que saca actualmente (acceso directo)
  Team get servingTeam => currentServer.team;

  factory MatchScore.fromJson(Map<String, dynamic> json) =>
      _$MatchScoreFromJson(json);
}
