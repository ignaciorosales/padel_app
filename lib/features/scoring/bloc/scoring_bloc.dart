import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// --- Compatibility layer ----------------------------------------------------
/// Lets the bloc run whether MatchSettings already has the new fields or not.
extension MatchSettingsCompat on MatchSettings {
  int get tbGames {
    try { return (this as dynamic).tieBreakAtGames as int; } catch (_) {}
    try {
      final bool sixSix = ((this as dynamic).tieBreakAtSixSix as bool?) ?? true;
      return sixSix ? 6 : 12;
    } catch (_) {}
    return 6;
  }

  bool get isGoldenPoint {
    try { return (this as dynamic).goldenPoint as bool; } catch (_) {}
    return false;
  }

  int get tbTarget {
    try { return (this as dynamic).tieBreakTarget as int; } catch (_) {}
    return 7;
  }
  
  /// Modo de partido: Amateur (0) o Campeonato (1)
  MatchMode get mode {
    try { return (this as dynamic).matchMode as MatchMode; } catch (_) {}
    return MatchMode.amateur;
  }
  
  bool get isChampionship => mode == MatchMode.championship;
  
  int get thirdSetFormat {
    // En modo campeonato, el tercer set siempre es Super Tie-Break a 11
    if (isChampionship) return 1;
    
    try { return (this as dynamic).thirdSetFormat as int; } catch (_) {}
    try { 
      final int tbGames = (this as dynamic).tieBreakAtGames as int;
      if (tbGames == 1) return 1; // Super TB
      if (tbGames >= 12) return 2; // Advantage set
      return 0; // Normal set
    } catch (_) {}
    return 0; // Por defecto, set normal
  }

  MatchSettings withTbGames(int games) {
    try { return (this as dynamic).copyWith(tieBreakAtGames: games) as MatchSettings; } catch (_) {}
    try { return (this as dynamic).copyWith(tieBreakAtSixSix: games == 6) as MatchSettings; } catch (_) {}
    return this;
  }

  MatchSettings withGoldenPoint(bool enabled) {
    try { return (this as dynamic).copyWith(goldenPoint: enabled) as MatchSettings; } catch (_) {}
    return this;
  }

  MatchSettings withTbTarget(int target) {
    try { return (this as dynamic).copyWith(tieBreakTarget: target) as MatchSettings; } catch (_) {}
    return this;
  }
  
  MatchSettings withThirdSetFormat(int format) {
    try { return (this as dynamic).copyWith(thirdSetFormat: format) as MatchSettings; } catch (_) {}
    try { 
      final int tbGames = format == 1 ? 1 : (format == 2 ? 12 : 6);
      return (this as dynamic).copyWith(tieBreakAtGames: tbGames) as MatchSettings; 
    } catch (_) {}
    return this;
  }
  
  MatchSettings withMatchMode(MatchMode newMode) {
    try { return (this as dynamic).copyWith(matchMode: newMode) as MatchSettings; } catch (_) {}
    return this;
  }
}
/// ---------------------------------------------------------------------------

class ScoringBloc extends Bloc<ScoringEvent, ScoringState> {
  ScoringBloc()
      : super(
          ScoringState(
            match: MatchScore(sets: const [SetScore()], currentSetIndex: 0),
          ),
        ) {
    on<NewMatchEvent>(_onNewMatch);
    on<NewSetEvent>(_onNewSet);
    on<NewGameEvent>(_onNewGame);

    on<PointForEvent>(_onPointFor);
    on<RemovePointEvent>(_onRemovePoint);
    on<ForceGameForEvent>(_onForceGameFor);
    on<ForceSetForEvent>(_onForceSetFor);
    on<SetExplicitGamePointsEvent>(_onSetExplicitGamePoints);

    on<ToggleTieBreakGamesEvent>(_onToggleTieBreakGamesEvent);
    on<ToggleTieBreakTargetEvent>(_onToggleTieBreakTargetEvent);
    on<ToggleGoldenPointEvent>(_onToggleGoldenPoint);
    on<SetMatchModeEvent>(_onSetMatchMode);

    on<AnnounceScoreEvent>(_onAnnounceScore);

    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<UndoForTeamEvent>(_onUndoForTeam);
    
    // Swap sides
    on<SwapSidesEvent>(_onSwapSides);
    on<ResetSwapEvent>(_onResetSwap);
  }

  final List<_ActionMeta> _undoMeta = [];

  // Helpers…

  bool _gameClosed(SetScore before, SetScore after) {
    final pointsReset = after.currentGame.blue == 0 && after.currentGame.red == 0;
    final gameInc = after.blueGames != before.blueGames || after.redGames != before.redGames;
    return pointsReset && gameInc;
  }

  Team _other(Team t) => t == Team.blue ? Team.red : Team.blue;

  /// Tiebreak serving order (1 serve, then 2/2 alternating)
  Team _tbNextServer(Team starter, int total) {
    if (total == 0) return starter;
    final block = ((total - 1) ~/ 2) % 2;
    return block == 0 ? _other(starter) : starter;
  }

  MatchScore _toggleServer(MatchScore m) {
    // Usar el nuevo sistema de servidor que rota entre los 4 jugadores
    final nextServer = m.currentServer.next();
    return m.copyWith(
      currentServer: nextServer,
      server: nextServer.team,
      receiver: _other(nextServer.team),
    );
  }

  /// Determines if the current set is over based on match mode and settings.
  /// 
  /// MODO AMATEUR:
  /// - Sets se juegan hasta diferencia de 2 juegos
  /// - En 5-5, se sigue jugando hasta diferencia de 2, máximo 9-8
  /// - NO hay tie-break en sets (solo diferencia de 2)
  /// 
  /// MODO CAMPEONATO:
  /// - En 6-6, se juega tie-break a 7 (diferencia de 2, sin límite)
  /// - En empate 1-1 de sets, se juega Super Tie-Break a 11
  bool _isSetOver(SetScore s, MatchSettings settings, [int? setIndex]) {
    final a = s.blueGames, b = s.redGames;
    
    // Verificar si es el tercer set (índice 2)
    final bool isThirdSet = setIndex == 2;
    final bool isChampionship = settings.mode == MatchMode.championship;
    
    // ========== MODO CAMPEONATO ==========
    if (isChampionship) {
      // En modo campeonato, el tercer set es un Super Tie-Break
      if (isThirdSet) {
        // Para Super Tie-Break, el set termina cuando se marca como 7-6 o 6-7
        // (estos valores se asignan cuando se completa el súper tie-break)
        if ((a == 7 && b == 6) || (a == 6 && b == 7)) return true;
        return false;
      }
      
      // Para sets normales en modo campeonato:
      // - Victoria 6-0 a 6-4 (diferencia de 2)
      if ((a >= 6 || b >= 6) && (a - b).abs() >= 2) return true;
      // - Victoria tras tie-break (7-6 o 6-7)
      if ((a == 7 && b == 6) || (a == 6 && b == 7)) return true;
      
      return false;
    }
    
    // ========== MODO AMATEUR ==========
    // En modo amateur, NO hay tie-break en sets
    // Se juega hasta diferencia de 2 juegos, con límite en 9-8
    
    // Victoria con diferencia de 2 (6-4, 7-5, 8-6, 9-7)
    if ((a >= 6 || b >= 6) && (a - b).abs() >= 2) return true;
    
    // Límite: si llegamos a 9-8, el set termina (máximo permitido)
    if ((a == 9 && b == 8) || (a == 8 && b == 9)) return true;
    
    // Seguridad: si algún equipo alcanza 10 juegos
    if (a >= 10 || b >= 10) return true;
    
    // Set no completado
    return false;
  }

  int _setsWonBy(MatchScore m, Team t, MatchSettings settings) {
    var won = 0;
    for (int i = 0; i < m.sets.length; i++) {
      final set = m.sets[i];
      final a = set.blueGames, b = set.redGames;
      
      // Verificar si el set está completado usando la misma lógica de _isSetOver
      final over = _isSetOver(set, settings, i);
      
      if (!over) continue;
      
      // Determinar el ganador del set
      if ((t == Team.blue && a > b) || (t == Team.red && b > a)) won++;
    }
    return won;
  }

  MatchScore _maybeAdvanceSet(MatchScore m) {
    final s = m.sets[m.currentSetIndex];
    final settings = m.settings;
    // Pasamos el índice del set actual para tener en cuenta el formato del tercer set
    if (!_isSetOver(s, settings, m.currentSetIndex)) return m;

    final blueSets = _setsWonBy(m, Team.blue, settings);
    final redSets  = _setsWonBy(m, Team.red, settings);
    final needs    = settings.setsToWin;

    // Verificar explícitamente si el partido ha terminado
    final matchOver = (blueSets >= needs || redSets >= needs);
    
    // Si el partido ha terminado, anunciar ganador
    if (matchOver) {
      final winner = getMatchWinner(m);
      
      // Si hay un ganador, mostramos un mensaje especial
      if (winner != null) {
        // Emitimos un evento para anunciar al ganador
        Future.delayed(const Duration(milliseconds: 100), () {
          add(const AnnounceScoreEvent());
        });
        
        // Añadimos un trofeo al nombre del ganador
        return m.copyWith(
          blueName: winner == Team.blue ? "${m.blueName} 🏆" : m.blueName,
          redName: winner == Team.red ? "${m.redName} 🏆" : m.redName,
        );
      }
      
      return m;
    }

    final newSets = [...m.sets, const SetScore()];
    final newIndex = newSets.length - 1;
    final isChampionship = settings.mode == MatchMode.championship;
    
    // Si estamos comenzando el tercer set (índice 2)
    if (newIndex == 2) {
      // En MODO CAMPEONATO, el tercer set es siempre un Super Tie-Break a 11
      if (isChampionship) {
        // Asegurarnos de que comienza con puntuación 0-0 y en modo tie-break
        newSets[newIndex] = SetScore(
          currentGame: const GamePoints(isTieBreak: true, blue: 0, red: 0),
          blueGames: 0,
          redGames: 0,
          tieBreakStarter: m.server,
          tieBreakStartServer: m.currentServer,
          isSuperTieBreak: true,
        );
      }
      // En MODO AMATEUR, el tercer set es un set normal (diferencia de 2, máximo 9-8)
    }
    
    return m.copyWith(sets: newSets, currentSetIndex: newIndex);
  }

  // Event handlers…

  void _onNewMatch(NewMatchEvent e, Emitter<ScoringState> emit) {
    final settings = e.settings ?? state.match.settings;
    final start = e.startingServer ?? Team.blue;
    final startServer = Server(team: start, position: PlayerPosition.drive);
    final next = MatchScore(
      sets: const [SetScore()],
      currentSetIndex: 0,
      currentServer: startServer,
      server: start,
      receiver: _other(start),
      settings: settings,
      blueName: state.match.blueName,
      redName: state.match.redName,
    );
    
    // Emitir estado con el partido reiniciado y sin ganador
    emit(state.copyWith(
      matchWinner: null,
      matchWinnerName: '',
      matchCompleted: false
    ));
    
    _pushHistory(emit, next, 'Nuevo partido');
  }

  void _onNewSet(NewSetEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    final newSets = [...m.sets, const SetScore()];
    final next = m.copyWith(sets: newSets, currentSetIndex: newSets.length - 1);
    _pushHistory(emit, next, 'Nuevo set');
  }

  void _onNewGame(NewGameEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    final idx = m.currentSetIndex;
    final updated = m.sets[idx].copyWith(currentGame: const GamePoints());
    final sets = m.sets.toList()..[idx] = updated;
    _pushHistory(emit, m.copyWith(sets: sets), 'Nuevo juego');
  }

  void _onPointFor(PointForEvent e, Emitter<ScoringState> emit) {
    var m = state.match;
    final idx   = m.currentSetIndex;
    final before= m.sets[idx];
    var set     = before;
    var skipGenericToggle = false;
    final isChampionship = m.settings.mode == MatchMode.championship;

    // Tie-break logic
    if (set.currentGame.isTieBreak) {
      final gp = set.currentGame;
      final nb = gp.blue + (e.team == Team.blue ? 1 : 0);
      final nr = gp.red + (e.team == Team.red  ? 1 : 0);

      final starter = set.tieBreakStarter ?? m.server;
      final starterServer = set.tieBreakStartServer ?? m.currentServer;
      
      // Determinar el objetivo del tie-break según:
      // - Super Tie-Break en modo CAMPEONATO: 11 puntos
      // - Super Tie-Break tradicional: 10 puntos
      // - Tie-break normal: 7 puntos
      final bool isSuperTieBreak = set.isSuperTieBreak;
      final int tgt;
      if (isSuperTieBreak) {
        tgt = isChampionship ? 11 : 10;  // 11 para campeonato, 10 para tradicional
      } else {
        tgt = 7;  // Tie-break normal siempre a 7
      }
      
      // Un tie-break se cierra cuando se alcanza el objetivo con diferencia de 2 puntos
      final tbClosed = (nb >= tgt || nr >= tgt) && (nb - nr).abs() >= 2;

      if (tbClosed) {
        // Determinar quién ganó el tie-break
        final winnerIsBlue = nb > nr;
        
        // Si es un Super Tie-Break, contar como set ganado
        if (isSuperTieBreak) {
          set = set.copyWith(
            blueGames: winnerIsBlue ? 7 : 6,
            redGames: winnerIsBlue ? 6 : 7,
            currentGame: const GamePoints(),
            tieBreakStarter: null,
            tieBreakStartServer: null,
          );
        } else {
          // Tie-break normal a 7, incrementa los juegos normalmente
          set = set.copyWith(
            blueGames: winnerIsBlue ? set.blueGames + 1 : set.blueGames,
            redGames: winnerIsBlue ? set.redGames : set.redGames + 1,
            currentGame: const GamePoints(),
            tieBreakStarter: null,
            tieBreakStartServer: null,
          );
        }
        
        // Después del tie-break, el servidor rota al siguiente jugador
        final nextServer = starterServer.next();
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          currentServer: nextServer,
          server: nextServer.team,
          receiver: _other(nextServer.team),
        );
        
        m = _maybeAdvanceSet(m);
        skipGenericToggle = true;
      } else {
        // Tie-break en progreso: rotación especial de saque
        // En tie-break, se rota el saque cada 2 puntos (excepto el primero)
        final total = nb + nr;
        final nextServer = _tbNextServer(starter, total);
        set = set.copyWith(
          currentGame: gp.copyWith(blue: nb, red: nr),
          tieBreakStarter: starter,
          tieBreakStartServer: starterServer,
        );
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          server: nextServer,
          receiver: _other(nextServer),
          // Nota: currentServer se mantiene durante el tie-break, solo cambia server/receiver
        );
      }
    } else {
      // Standard game logic (with or without golden point)
      set = _advanceStandardPoint(set, e.team, m.settings.isGoldenPoint);

      // Verificar si debemos activar un tie-break en 6-6
      final isThirdSet = idx == 2;
      
      // MODO CAMPEONATO: tie-break en 6-6 para sets 1-2, super TB en tercer set
      // MODO AMATEUR: NO hay tie-break, se juega hasta diferencia de 2 (máx 9-8)
      if (isChampionship) {
        // En modo campeonato, activar tie-break en 6-6 (solo sets 1-2)
        // El tercer set ya se maneja como Super TB desde _maybeAdvanceSet
        if (!isThirdSet && set.blueGames == 6 && set.redGames == 6 && !set.currentGame.isTieBreak) {
          set = set.copyWith(
            currentGame: const GamePoints(isTieBreak: true),
            tieBreakStarter: m.server,
            tieBreakStartServer: m.currentServer,
            isSuperTieBreak: false,
          );
        }
      }
      // En modo amateur: NO se activa tie-break, se sigue jugando hasta diferencia de 2
      
      m = m.copyWith(sets: (m.sets.toList()..[idx] = set));
    }

    if (!skipGenericToggle && _gameClosed(before, set)) {
      m = _toggleServer(m);
      m = _maybeAdvanceSet(m);
    }

    final teamName = e.team == Team.blue ? state.match.blueName : state.match.redName;
    _pushHistory(emit, m, 'Punto $teamName', actorTeam: e.team, actionType: 'point');
  }

  SetScore _advanceStandardPoint(SetScore set, Team team, bool goldenPoint) {
    final gp = set.currentGame;
    int b = gp.blue, r = gp.red;

    // Apply the point
    if (team == Team.blue) {
      b++;
    } else {
      r++;
    }

    if (goldenPoint) {
      // No-adv: as soon as someone reaches 4 points, the game is over.
      if (b >= 4 || r >= 4) {
        final blueWins = b > r;
        return set.copyWith(
          blueGames: set.blueGames + (blueWins ? 1 : 0),
          redGames : set.redGames  + (blueWins ? 0 : 1),
          currentGame: const GamePoints(),
        );
      }
      // Still in progress
      return set.copyWith(currentGame: gp.copyWith(blue: b, red: r));
    }

    // Traditional advantage scoring:
    // Once someone has 4 or more, check the margin.
    if (b >= 4 || r >= 4) {
      final diff = b - r;
      if (diff >= 2) {
        return set.copyWith(
          blueGames: set.blueGames + 1,
          currentGame: const GamePoints(),
        );
      }
      if (diff <= -2) {
        return set.copyWith(
          redGames: set.redGames + 1,
          currentGame: const GamePoints(),
        );
      }
    }

    // Game not finished yet
    return set.copyWith(currentGame: gp.copyWith(blue: b, red: r));
  }

  void _onRemovePoint(RemovePointEvent e, Emitter<ScoringState> emit) {
    final m   = _clone(state.match);
    final idx = m.currentSetIndex;
    final gp  = m.sets[idx].currentGame;
    final nb  = e.team == Team.blue ? (gp.blue > 0 ? gp.blue - 1 : 0) : gp.blue;
    final nr  = e.team == Team.red  ? (gp.red  > 0 ? gp.red  - 1 : 0) : gp.red;
    final updatedSet = m.sets[idx].copyWith(currentGame: gp.copyWith(blue: nb, red: nr));
    final sets = m.sets.toList()..[idx] = updatedSet;
    final teamName = e.team == Team.blue ? state.match.blueName : state.match.redName;
    _pushHistory(emit, m.copyWith(sets: sets), 'Quitar punto $teamName',
      actorTeam: e.team, actionType: 'remove-point');
  }

  void _onForceGameFor(ForceGameForEvent e, Emitter<ScoringState> emit) {
    var m = _clone(state.match);
    final idx = m.currentSetIndex;
    final set = m.sets[idx];
    final updated = set.copyWith(
      blueGames: set.blueGames + (e.team == Team.blue ? 1 : 0),
      redGames: set.redGames + (e.team == Team.red ? 1 : 0),
      currentGame: const GamePoints(),
    );
    m = m.copyWith(sets: m.sets.toList()..[idx] = updated);
    m = _toggleServer(m);
    m = _maybeAdvanceSet(m);
    _pushHistory(emit, m, 'Juego forzado', actorTeam: e.team, actionType: 'force-game');
  }

  void _onForceSetFor(ForceSetForEvent e, Emitter<ScoringState> emit) {
    var m = _clone(state.match);
    final updated = m.sets.toList();
    final idx = m.currentSetIndex;
    final set = updated[idx];
    
    // Dependiendo del formato del tercer set, forzamos diferentes valores
    int targetGames = 6; // Por defecto, 6 juegos
    
    if (idx == 2) {
      final thirdSetFormat = m.settings.thirdSetFormat;
      if (thirdSetFormat == 1) {
        // Para Super Tie-Break, asignamos directamente 7-6 o 6-7
        updated[idx] = set.copyWith(
          blueGames: e.team == Team.blue ? 7 : 6,
          redGames: e.team == Team.red ? 7 : 6,
          currentGame: const GamePoints(),
        );
        m = m.copyWith(sets: updated);
        m = _maybeAdvanceSet(m);
        
        // Verificar si el partido ha terminado
        final matchComplete = isMatchCompleted(m);
        if (matchComplete) {
          // Anunciar ganador
          Future.delayed(const Duration(milliseconds: 100), () {
            add(const AnnounceScoreEvent());
          });
        }
        
        _pushHistory(
          emit,
          m,
          matchComplete ? 'Partido finalizado (Super TB)' : 'Set forzado (Super TB)',
          actorTeam: e.team,
          actionType: 'force-set'
        );
        return;
      } else if (thirdSetFormat == 2) {
        // Para set con ventaja, necesitamos asegurar una diferencia de 2 juegos
        final blueGames = set.blueGames;
        final redGames = set.redGames;
        
        if (e.team == Team.blue) {
          // Si gana el verde, asegurar que tiene al menos 6 juegos y 2 más que el negro
          final newBlueGames = math.max(6, blueGames);
          final newRedGames = newBlueGames - 2;
          updated[idx] = set.copyWith(
            blueGames: newBlueGames,
            redGames: math.max(0, newRedGames), // Evitar negativos
            currentGame: const GamePoints(),
          );
        } else {
          // Si gana el negro, asegurar que tiene al menos 6 juegos y 2 más que el verde
          final newRedGames = math.max(6, redGames);
          final newBlueGames = newRedGames - 2;
          updated[idx] = set.copyWith(
            redGames: newRedGames,
            blueGames: math.max(0, newBlueGames), // Evitar negativos
            currentGame: const GamePoints(),
          );
        }
        m = m.copyWith(sets: updated);
        m = _maybeAdvanceSet(m);
        
        // Verificar si el partido ha terminado
        final matchComplete = isMatchCompleted(m);
        if (matchComplete) {
          // Anunciar ganador
          Future.delayed(const Duration(milliseconds: 100), () {
            add(const AnnounceScoreEvent());
          });
        }
        
        _pushHistory(
          emit,
          m,
          matchComplete ? 'Partido finalizado (ventaja)' : 'Set forzado (ventaja)',
          actorTeam: e.team,
          actionType: 'force-set'
        );
        return;
      }
    }
    
    // Para sets normales o los dos primeros sets
    updated[idx] = set.copyWith(
      blueGames: e.team == Team.blue
          ? (set.blueGames >= targetGames ? set.blueGames : targetGames)
          : set.blueGames,
      redGames: e.team == Team.red
          ? (set.redGames >= targetGames ? set.redGames : targetGames)
          : set.redGames,
      currentGame: const GamePoints(),
    );
    m = m.copyWith(sets: updated);
    m = _maybeAdvanceSet(m);
    
    // Verificar si el partido ha terminado
    final matchComplete = isMatchCompleted(m);
    if (matchComplete) {
      // Anunciar ganador
      Future.delayed(const Duration(milliseconds: 100), () {
        add(const AnnounceScoreEvent());
      });
    }
    
    _pushHistory(
      emit,
      m,
      matchComplete ? 'Partido finalizado' : 'Set forzado',
      actorTeam: e.team,
      actionType: 'force-set'
    );
  }

  void _onSetExplicitGamePoints(SetExplicitGamePointsEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    final idx = m.currentSetIndex;
    final updated = m.sets[idx].copyWith(currentGame: GamePoints(blue: e.blue, red: e.red));
    final sets = m.sets.toList()..[idx] = updated;
    _pushHistory(emit, m.copyWith(sets: sets), 'Fijar puntos de juego');
  }

  void _onToggleTieBreakGamesEvent(ToggleTieBreakGamesEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    
    // ACTUALIZACIÓN: Ahora utilizamos thirdSetFormat en lugar de tbGames
    // e.games == 1 significa Super Tie-Break (formato 1)
    // e.games == 6 significa set normal (formato 0)
    // e.games == 12 significa set ventaja sin tie-break (formato 2)
    
    int thirdSetFormat = 0; // Default: set normal
    if (e.games == 1) thirdSetFormat = 1; // Super TB
    else if (e.games >= 12) thirdSetFormat = 2; // Advantage set
    
    // Configurar el formato del tercer set
    
    // Actualizar la configuración
    final settings = m.settings
                      .withTbGames(e.games) // Para compatibilidad
                      .withThirdSetFormat(thirdSetFormat);
    
    // Verificar si estamos en el tercer set activo
    final bool isInThirdSet = m.currentSetIndex == 2 && 
                             m.sets.length > 2 && 
                             !_isSetOver(m.sets[2], m.settings, 2);
    
    // Si estamos en el tercer set activo, actualizar el juego en curso
    if (isInThirdSet) {
      final currentSet = m.sets[2];
      
      // Siempre resetear el juego actual a cero para evitar inconsistencias
      GamePoints newGamePoints;
      bool isSuperTB = false;
      
      // Configurar el juego según el formato elegido
      if (thirdSetFormat == 1) { // Super TB
        newGamePoints = const GamePoints(isTieBreak: true, blue: 0, red: 0);
        isSuperTB = true;
      } else {
        // Set normal o con ventaja: juego normal
        newGamePoints = const GamePoints(isTieBreak: false, blue: 0, red: 0);
      }
      
      // Actualizar el set actual
      final updatedSet = currentSet.copyWith(
        currentGame: newGamePoints,
        tieBreakStarter: thirdSetFormat == 1 ? m.server : null,
        isSuperTieBreak: isSuperTB,
      );
      
      // Actualizar el set en la lista de sets
      final updatedSets = m.sets.toList();
      updatedSets[2] = updatedSet;
      
      // Nombres para los diferentes formatos
      String formatName = "";
      if (thirdSetFormat == 0) formatName = "set normal";
      else if (thirdSetFormat == 1) formatName = "Super TB a 10";
      else if (thirdSetFormat == 2) formatName = "set con ventaja";
      
      _pushHistory(
        emit,
        m.copyWith(
          settings: settings,
          sets: updatedSets,
        ),
        'Cambiado a $formatName en el 3er set',
        actionType: 'config:third-set-format',
      );
      return;
    }
    
    // Si no estamos en el tercer set, simplemente actualizamos la configuración
    String formatName = "";
    if (thirdSetFormat == 0) formatName = "set normal";
    else if (thirdSetFormat == 1) formatName = "Super TB a 10";
    else if (thirdSetFormat == 2) formatName = "set con ventaja";
    
    _pushHistory(
      emit,
      m.copyWith(settings: settings),
      'Configurado $formatName para 3er set',
      actionType: 'config:third-set-format',
    );
  }

  void _onToggleTieBreakTargetEvent(ToggleTieBreakTargetEvent e, Emitter<ScoringState> emit) {
    // Este método se mantiene por compatibilidad pero ya no se usa.
    // El target del tie-break ahora se determina por set:
    // - Regular tie-breaks: 7 puntos (en 6-6 del primer y segundo set)
    // - Super tie-breaks: 10 puntos (en tercer set con formato 1)
    
    // Emitimos un mensaje informativo pero no cambiamos nada
    emit(state.copyWith(
      lastActionLabel: 'Tie-break a ${e.target} puntos',
    ));
  }

  void _onToggleGoldenPoint(ToggleGoldenPointEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    _pushHistory(
      emit,
      m.copyWith(settings: m.settings.withGoldenPoint(e.enabled)),
      'Punto de oro: ${e.enabled ? 'ON' : 'OFF'}',
      actionType: 'config:golden-point',
    );
  }

  void _onSetMatchMode(SetMatchModeEvent e, Emitter<ScoringState> emit) {
    // Al cambiar el modo de partido, resetear el partido actual
    final currentSettings = state.match.settings;
    final newSettings = currentSettings.withMatchMode(e.mode);
    final modeName = e.mode == MatchMode.championship ? 'Campeonato' : 'Amateur';
    
    // Crear nuevo partido con las nuevas configuraciones
    final startServer = Server(team: state.match.currentServer.team, position: PlayerPosition.drive);
    final newMatch = MatchScore(
      sets: const [SetScore()],
      currentSetIndex: 0,
      currentServer: startServer,
      server: startServer.team,
      receiver: _other(startServer.team),
      settings: newSettings,
      blueName: state.match.blueName.replaceAll(' 🏆', ''),
      redName: state.match.redName.replaceAll(' 🏆', ''),
    );
    
    // Resetear estado completo incluyendo ganador
    emit(state.copyWith(
      match: newMatch,
      undoStack: const [],
      redoStack: const [],
      matchWinner: null,
      matchWinnerName: '',
      matchCompleted: false,
      isSwapped: false,
      lastActionLabel: 'Modo: $modeName (partido reiniciado)',
    ));
    
    _undoMeta.clear();
  }

  void _onAnnounceScore(AnnounceScoreEvent e, Emitter<ScoringState> emit) {
    final m = state.match;
    
    // Verificar si el partido ha terminado
    if (isMatchCompleted(m)) {
      final winner = getMatchWinner(m);
      if (winner != null) {
        final winnerName = winner == Team.blue ? m.blueName : m.redName;
        final cleanWinnerName = winnerName.contains("🏆") ? 
            winnerName.substring(0, winnerName.indexOf(" 🏆")) : winnerName;
        final blueSets = _setsWonBy(m, Team.blue, m.settings);
        final redSets = _setsWonBy(m, Team.red, m.settings);
        
        // Configurar el estado de ganador
        emit(state.copyWith(
          matchWinner: winner,
          matchWinnerName: cleanWinnerName,
          matchCompleted: true,
          lastAnnouncement: '¡$cleanWinnerName GANA EL PARTIDO! (${blueSets}-${redSets})'
        ));
        
        // Programar el reinicio automático después de un retraso
        Future.delayed(const Duration(seconds: 8), () {
          add(NewMatchEvent(
            settings: m.settings,
            startingServer: m.server, // mantener el mismo servidor
          ));
        });
        
        return;
      }
    }
    
    // Si no hay ganador, anuncio normal
    final cur = m.currentSet.currentGame;
    String gp(int v) => v == 0 ? '0' : v == 1 ? '15' : v == 2 ? '30' : v == 3 ? '40' : 'AD';
    final text = cur.isTieBreak
        ? 'Tiebreak ${m.blueName} ${cur.blue} – ${cur.red} ${m.redName}'
        : '${m.blueName} ${gp(cur.blue)} – ${gp(cur.red)} ${m.redName} '
          '(Juegos ${m.currentSet.blueGames}-${m.currentSet.redGames})';
    emit(state.copyWith(lastAnnouncement: text));
  }

  void _onUndo(UndoEvent e, Emitter<ScoringState> emit) {
    if (state.undoStack.isEmpty) return;
    
    // Buscar la última acción que no sea de configuración
    int idx = state.undoStack.length - 1;
    
    while (idx >= 0) {
      // Verificar si tenemos metadatos para esta acción
      if (idx < _undoMeta.length) {
        final meta = _undoMeta[idx];
        // Si es una acción de puntos (no de configuración), entonces la deshacemos
        if (!_isConfigEvent(meta.type)) {
          break;
        }
      }
      idx--;
    }
    
    if (idx < 0) return; // No hay acciones de puntos para deshacer
    
    final prev = state.undoStack[idx];
    
    // Mantener todas las configuraciones actuales:
    // 1. Punto de oro (golden point)
    // 2. Tipo de tercer set (Super Tie-Break o set normal)
    // 3. Objetivo del tie-break (7 o 10 puntos)
    final currentSettings = state.match.settings;
    final updatedPrev = prev.copyWith(settings: currentSettings);
    
    emit(state.copyWith(
      match: updatedPrev,
      undoStack: state.undoStack.take(idx).toList(),
      redoStack: [...state.redoStack, state.match],
      lastActionLabel: 'Deshacer',
    ));
    
    // Actualizar _undoMeta para mantener sincronización
    if (_undoMeta.isNotEmpty) {
      _undoMeta.removeRange(idx, _undoMeta.length);
    }
  }
  
  void _onRedo(RedoEvent e, Emitter<ScoringState> emit) {
    if (state.redoStack.isEmpty) return;
    
    // Buscar la siguiente acción que no sea de configuración
    int idx = 0;
    final redoLength = state.redoStack.length;
    
    while (idx < redoLength) {
      final nextState = state.redoStack[idx];
      // Solo rehacer acciones de puntos, no de configuración
      if (_isActionRelatedToPoints(state.match, nextState)) {
        break;
      }
      idx++;
    }
    
    if (idx >= redoLength) return; // No hay acciones de puntos para rehacer
    
    final next = state.redoStack[idx];
    
    // Mantener todas las configuraciones actuales
    final currentSettings = state.match.settings;
    final updatedNext = next.copyWith(settings: currentSettings);
    
    emit(state.copyWith(
      match: updatedNext,
      redoStack: state.redoStack.sublist(idx + 1),
      undoStack: [...state.undoStack, state.match],
      lastActionLabel: 'Rehacer',
    ));
    
    // Push placeholder meta
    _undoMeta.add(_ActionMeta(null, 'redo'));
  }
  
  // Determina si un cambio es de puntos (no de configuración)
  bool _isActionRelatedToPoints(MatchScore current, MatchScore next) {
    // Si cambia la configuración de tie-break, es un cambio de configuración
    if (current.settings.tbGames != next.settings.tbGames) {
      return false; // Cambio de tipo de tercer set (normal vs Super TB)
    }
    
    // Si cambia la configuración de punto de oro, es un cambio de configuración
    if (current.settings.goldenPoint != next.settings.goldenPoint) {
      return false; // Cambio de configuración de punto de oro
    }
    
    // Si cambia el objetivo del tie-break, es un cambio de configuración
    if (current.settings.tbTarget != next.settings.tbTarget) {
      return false; // Cambio de objetivo del tie-break (7 vs 10)
    }
    
    // Si cambian los puntos, es un cambio relacionado con puntos
    final curSet = current.currentSet;
    final nextSet = next.currentSet;
    
    // Comparar puntos del juego actual
    if (curSet.currentGame.blue != nextSet.currentGame.blue || 
        curSet.currentGame.red != nextSet.currentGame.red) {
      return true;
    }
    
    // Comparar juegos del set
    if (curSet.blueGames != nextSet.blueGames || 
        curSet.redGames != nextSet.redGames) {
      return true;
    }
    
    // Comparar número de sets
    if (current.sets.length != next.sets.length) {
      return true;
    }
    
    // No es un cambio de puntos
    return false;
  }
  
  // Determina si un evento es de configuración (no de puntos)
  bool _isConfigEvent(String type) {
    return type.contains('Tie-break') || 
           type.contains('Punto de oro') || 
           type.contains('Super TB') || 
           type.contains('set normal') || 
           type.startsWith('config:') ||
           type == 'Cambiar servicio';
  }

  void _onUndoForTeam(UndoForTeamEvent e, Emitter<ScoringState> emit) {
    // UNDO_A solo funciona si la ÚLTIMA acción fue del equipo A
    // UNDO_B solo funciona si la ÚLTIMA acción fue del equipo B
    // Esto evita que un equipo deshaga los puntos del contrario
    
    if (state.undoStack.isEmpty || _undoMeta.isEmpty) return;
    
    // Buscar la última acción de puntos (ignorando configuraciones)
    int metaIdx = _undoMeta.length - 1;
    while (metaIdx >= 0) {
      final meta = _undoMeta[metaIdx];
      if (!_isConfigEvent(meta.type)) {
        break;
      }
      metaIdx--;
    }
    
    if (metaIdx < 0) return; // No hay acciones de puntos
    
    final lastMeta = _undoMeta[metaIdx];
    
    // Solo permitir deshacer si la última acción fue de ESTE equipo
    if (lastMeta.team != e.team) {
      // La última acción no fue de este equipo, no hacer nada
      return;
    }
    
    // Deshacer la última acción (que es de este equipo)
    if (metaIdx >= state.undoStack.length) return;
    
    final target = state.undoStack[metaIdx];
    final newUndo = state.undoStack.take(metaIdx).toList();
    
    // Mantener configuraciones actuales
    final currentSettings = state.match.settings;
    final updatedTarget = target.copyWith(settings: currentSettings);

    emit(state.copyWith(
      match: updatedTarget,
      undoStack: newUndo,
      redoStack: [...state.redoStack, state.match],
      lastActionLabel: 'Deshacer (${e.team == Team.blue ? 'A' : 'B'})',
    ));

    // Trim meta to match newUndo length
    _undoMeta.removeRange(metaIdx, _undoMeta.length);
  }

  // Helper to deep-clone the match state (for undo/redo)
  MatchScore _clone(MatchScore m) =>
      m.copyWith(sets: m.sets.map((s) => s.copyWith()).toList());

  // Determinar si el partido ha terminado (algún equipo alcanzó los sets necesarios)
  bool isMatchCompleted(MatchScore m) {
    final settings = m.settings;
    final blueSets = _setsWonBy(m, Team.blue, settings);
    final redSets = _setsWonBy(m, Team.red, settings);
    final needs = settings.setsToWin;
    
    return (blueSets >= needs || redSets >= needs);
  }
  
  // Determinar el equipo ganador del partido (null si no ha terminado)
  Team? getMatchWinner(MatchScore m) {
    final settings = m.settings;
    final blueSets = _setsWonBy(m, Team.blue, settings);
    final redSets = _setsWonBy(m, Team.red, settings);
    final needs = settings.setsToWin;
    
    if (blueSets >= needs) return Team.blue;
    if (redSets >= needs) return Team.red;
    return null;
  }

  void _pushHistory(
    Emitter<ScoringState> emit,
    MatchScore next,
    String label, {
    Team? actorTeam,
    String? actionType,
  }) {
    emit(state.copyWith(
      undoStack: [...state.undoStack, state.match],
      redoStack: const [],
      match: next,
      lastActionLabel: label,
    ));
    _undoMeta.add(_ActionMeta(actorTeam, actionType ?? label));
  }
  
  // ============ SWAP SIDES ============
  
  void _onSwapSides(SwapSidesEvent event, Emitter<ScoringState> emit) {
    emit(state.copyWith(isSwapped: !state.isSwapped));
  }
  
  void _onResetSwap(ResetSwapEvent event, Emitter<ScoringState> emit) {
    emit(state.copyWith(isSwapped: false));
  }
}

class _ActionMeta {
  final Team? team;
  final String type;
  _ActionMeta(this.team, this.type);
}
