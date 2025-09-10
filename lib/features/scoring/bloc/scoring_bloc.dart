import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';

/// --- Compatibility layer ----------------------------------------------------
/// Lets the bloc run whether MatchSettings already has the new fields or not.
/// Remove this once your MatchSettings definitively includes:
/// - int tieBreakAtGames
/// - bool goldenPoint
/// - int tieBreakTarget
extension MatchSettingsCompat on MatchSettings {
  int get tbGames {
    try { return (this as dynamic).tieBreakAtGames as int; } catch (_) {}
    // Legacy fallback: if you had a boolean tieBreakAtSixSix
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

    // Rules
    on<ToggleTieBreakGamesEvent>(_onToggleTieBreakGamesEvent);
    on<ToggleTieBreakTargetEvent>(_onToggleTieBreakTargetEvent);
    on<ToggleGoldenPointEvent>(_onToggleGoldenPoint);

    // Optional announcer
    on<AnnounceScoreEvent>(_onAnnounceScore);

    // Undo/redo
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);

    // BLE + team-undo
    on<BleCommandEvent>(_onBleCommand);
    on<UndoForTeamEvent>(_onUndoForTeam);
  }

  // Mapping A/B to Team.blue/Team.red…
  final Team _teamA = Team.blue;
  final Team _teamB = Team.red;

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
    final nextServer = _other(m.server);
    return m.copyWith(
      server: nextServer,
      receiver: _other(nextServer),
    );
  }

  /// Determines if the current set is over based on user-configurable settings.
  bool _isSetOver(SetScore s, MatchSettings settings) {
    final a = s.blueGames, b = s.redGames;
    final tbGames = settings.tbGames;
    
    // Caso especial: Super Tie-Break en el tercer set (representado por un set 7-6 o 6-7)
    if ((a == 7 && b == 6) || (a == 6 && b == 7)) return true;
    
    // Si estamos en modo Super Tie-Break (tbGames = 1), esto solo aplica al tercer set
    // y es manejado por la lógica especial en _onPointFor. Para los sets normales,
    // el valor de tbGames debe ser 6.
    final effectiveTbGames = tbGames == 1 ? 6 : tbGames;
    
    // Victoria por diferencia de 2 juegos cuando al menos uno alcanza el umbral de tie-break
    if ((a >= effectiveTbGames || b >= effectiveTbGames) && (a - b).abs() >= 2) return true;
    
    // Después de un tie-break, un lado alcanzará tbGames+1 (p.ej. 7 en un tie-break a 6-6)
    if (a >= effectiveTbGames + 1 || b >= effectiveTbGames + 1) return true;
    
    return false;
  }

  int _setsWonBy(MatchScore m, Team t, MatchSettings settings) {
    var won = 0;
    for (final s in m.sets) {
      final a = s.blueGames, b = s.redGames;
      final tbGames = settings.tbGames;
      
      // Si estamos en modo Super Tie-Break (tbGames = 1), esto solo aplica al tercer set.
      // Para los sets normales, el valor de tbGames debe ser 6.
      final effectiveTbGames = tbGames == 1 ? 6 : tbGames;
      
      // Caso especial: Super Tie-Break (7-6 o 6-7 en el tercer set)
      final isSuperTieBreakWin = (a == 7 && b == 6) || (a == 6 && b == 7);
      
      // Condiciones normales de victoria de set
      final over = isSuperTieBreakWin || 
                   ((a >= effectiveTbGames || b >= effectiveTbGames) && (a - b).abs() >= 2) ||
                   (a >= effectiveTbGames + 1 || b >= effectiveTbGames + 1);
                   
      if (!over) continue;
      
      // En caso de Super Tie-Break, verificar específicamente
      if (isSuperTieBreakWin) {
        if ((t == Team.blue && a > b) || (t == Team.red && b > a)) won++;
      } else {
        // Victoria normal de set
        if ((t == Team.blue && a > b) || (t == Team.red && b > a)) won++;
      }
    }
    return won;
  }

  MatchScore _maybeAdvanceSet(MatchScore m) {
    final s = m.sets[m.currentSetIndex];
    final settings = m.settings;
    if (!_isSetOver(s, settings)) return m;

    final blueSets = _setsWonBy(m, Team.blue, settings);
    final redSets  = _setsWonBy(m, Team.red, settings);
    final needs    = settings.setsToWin;

    final matchOver = (blueSets >= needs || redSets >= needs);
    if (matchOver) return m;

    final newSets = [...m.sets, const SetScore()];
    final newIndex = newSets.length - 1;
    
    // Si estamos comenzando el tercer set (índice 2) y está configurado como Super Tie-Break (tbGames == 1)
    // marcamos el juego como tie-break inmediatamente y establecemos el objetivo a 10 puntos
    if (newIndex == 2 && settings.tbGames == 1) {
      // Crear una copia con el tie-break target a 10 puntos para el Super Tie-Break
      final superTbSettings = settings.withTbTarget(10);
      
      // Asegurarnos de que comienza con puntuación 0-0 y en modo tie-break
      newSets[newIndex] = const SetScore(
        currentGame: GamePoints(isTieBreak: true, blue: 0, red: 0),
        blueGames: 0,
        redGames: 0,
      );
      
      // Guardar el servidor de inicio del tie-break
      newSets[newIndex] = newSets[newIndex].copyWith(
        tieBreakStarter: m.server,
      );
      
      // Actualizar la configuración para el Super Tie-Break
      m = m.copyWith(settings: superTbSettings);
    }
    
    return m.copyWith(sets: newSets, currentSetIndex: newIndex);
  }

  // Event handlers…

  void _onNewMatch(NewMatchEvent e, Emitter<ScoringState> emit) {
    final settings = e.settings ?? state.match.settings;
    final start = e.startingServer ?? Team.blue;
    final next = MatchScore(
      sets: const [SetScore()],
      currentSetIndex: 0,
      server: start,
      receiver: _other(start),
      settings: settings,
      blueName: state.match.blueName,
      redName: state.match.redName,
    );
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
    var m = _clone(state.match);
    final idx   = m.currentSetIndex;
    final before= m.sets[idx];
    var set     = before;
    var skipGenericToggle = false;

    // Tie-break logic
    if (set.currentGame.isTieBreak) {
      final gp = set.currentGame;
      final nb = gp.blue + (e.team == Team.blue ? 1 : 0);
      final nr = gp.red + (e.team == Team.red  ? 1 : 0);

      final starter = set.tieBreakStarter ?? m.server;
      
      // Determinar el objetivo del tie-break
      // - Para Super Tie-Break (tercer set con tbGames=1): 10 puntos
      // - Para tie-break normal: 7 puntos
      final bool isSuperTieBreak = idx == 2 && m.settings.tbGames == 1;
      final tgt = isSuperTieBreak ? 10 : 7;
      
      // Un tie-break se cierra cuando se alcanza el objetivo con diferencia de 2 puntos
      final tbClosed = (nb >= tgt || nr >= tgt) && (nb - nr).abs() >= 2;

      if (tbClosed) {
        // Determinar quién ganó el tie-break
        final winnerIsBlue = nb > nr;
        
        // Si es un Super Tie-Break en el tercer set, contar como set ganado, no como juego
        if (isSuperTieBreak) {
          // En el Super Tie-Break, directamente damos por ganado el set
          // No incrementamos juegos, porque este tie-break representa el set completo
          set = set.copyWith(
            // Asignamos un valor alto (como 7-6 o 6-7) para indicar que el set está cerrado
            blueGames: winnerIsBlue ? 7 : 6,
            redGames: winnerIsBlue ? 6 : 7,
            currentGame: const GamePoints(),
            tieBreakStarter: null,
          );
        } else {
          // Tie-break normal a 7, incrementa los juegos normalmente
          set = set.copyWith(
            blueGames: winnerIsBlue ? set.blueGames + 1 : set.blueGames,
            redGames: winnerIsBlue ? set.redGames : set.redGames + 1,
            currentGame: const GamePoints(),
            tieBreakStarter: null,
          );
        }
        
        final nextServer = _other(starter);
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          server: nextServer,
          receiver: _other(nextServer),
        );
        
        m = _maybeAdvanceSet(m);
        skipGenericToggle = true;
      } else {
        // Tie-break en progreso
        final total = nb + nr;
        final nextServer = _tbNextServer(starter, total);
        set = set.copyWith(
          currentGame: gp.copyWith(blue: nb, red: nr),
          tieBreakStarter: starter,
        );
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          server: nextServer,
          receiver: _other(nextServer),
        );
      }
    } else {
      // Standard game logic (with or without golden point)
      set = _advanceStandardPoint(set, e.team, m.settings.isGoldenPoint);

      // Start a tiebreak if both teams reach tieBreakAtGames games
      final tbGames = m.settings.tbGames;
      
      // Si estamos en modo Super Tie-Break (tbGames = 1), esto solo aplica al tercer set.
      // Para los sets normales, el valor efectivo debe ser 6.
      final effectiveTbGames = tbGames == 1 ? 6 : tbGames;
      
      if (set.blueGames == effectiveTbGames && set.redGames == effectiveTbGames && !set.currentGame.isTieBreak) {
        set = set.copyWith(
          currentGame: const GamePoints(isTieBreak: true),
          tieBreakStarter: m.server,
        );
      }
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
    final targetGames = m.settings.tbGames;
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
    _pushHistory(emit, m, 'Set forzado', actorTeam: e.team, actionType: 'force-set');
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
    
    // Si se cambia a Super Tie-Break (e.games == 1), asegurarse de que el objetivo sea 10 puntos
    // Si se cambia a set normal (e.games == 6), establecer el objetivo a 7 puntos para tie-breaks normales
    final int tieBreakTarget = e.games == 1 ? 10 : 7;
    final settings = m.settings.withTbGames(e.games).withTbTarget(tieBreakTarget);
    
    // Verificar si realmente estamos en el tercer set activo
    // - El índice actual debe ser 2 (tercer set)
    // - Debe existir realmente el tercer set en la lista
    // - El tercer set debe estar activo (no terminado)
    final bool isInThirdSet = m.currentSetIndex == 2 && 
                            m.sets.length > 2 && 
                            !_isSetOver(m.sets[2], m.settings);
    
    // Si estamos en el tercer set activo, actualizar el juego en curso
    if (isInThirdSet) {
      final currentSet = m.sets[2];
      
      // Siempre resetear el juego actual a cero para evitar inconsistencias
      GamePoints newGamePoints;
      
      // Si cambiamos a Super TB (valor 1), convertir a tie-break
      if (e.games == 1) {
        newGamePoints = const GamePoints(isTieBreak: true, blue: 0, red: 0);
      } else {
        // Si cambiamos a set normal, convertir a juego normal
        newGamePoints = const GamePoints(isTieBreak: false, blue: 0, red: 0);
      }
      
      // Actualizar el set actual con los puntos reseteados
      final updatedSet = currentSet.copyWith(
        currentGame: newGamePoints,
        // Guardar o eliminar el servidor de inicio del TB según corresponda
        tieBreakStarter: e.games == 1 ? m.server : null,
      );
      
      // Actualizar el set en la lista de sets
      final updatedSets = m.sets.toList();
      updatedSets[2] = updatedSet;
      
      _pushHistory(
        emit,
        m.copyWith(
          settings: settings,
          sets: updatedSets,
        ),
        e.games == 1 ? 'Cambiado a Super TB en el 3er set' : 'Cambiado a set normal en el 3er set',
        actionType: 'config:tie-break-games',
      );
      return;
    }
    
    // Si no estamos en el tercer set, simplemente actualizamos la configuración
    // pero no afectamos el set actual en progreso
    _pushHistory(
      emit,
      m.copyWith(settings: settings),
      e.games == 1 ? 'Configurado Super TB para 3er set' : 'Configurado set normal para 3er set',
      actionType: 'config:tie-break-games',
    );
  }

  void _onToggleTieBreakTargetEvent(ToggleTieBreakTargetEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    _pushHistory(
      emit,
      m.copyWith(settings: m.settings.withTbTarget(e.target)),
      'Tie-break a ${e.target} puntos',
      actionType: 'config:tie-break-target',
    );
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

  void _onAnnounceScore(AnnounceScoreEvent e, Emitter<ScoringState> emit) {
    final m = state.match;
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

  // ========== BLE bridge ==========
  void _onBleCommand(BleCommandEvent e, Emitter<ScoringState> emit) {
    final cmd = e.cmd.trim().toLowerCase();

    if (cmd == 'cmd:toggle-server') {
      final m = _clone(state.match);
      final nextServer = _other(m.server);
      final next = m.copyWith(
        server: nextServer,
        receiver: _other(nextServer),
      );
      _pushHistory(emit, next, 'Cambiar servicio', actionType: 'config:toggle-server');
      return;
    }

    // existing behavior
    if (cmd.startsWith('cmd:')) {
      final ch = cmd.substring(4);
      if (ch.isEmpty) return;
      _dispatchCmd(ch[0]);
    } else if (cmd.isNotEmpty) {
      _dispatchCmd(cmd[0]);
    }
  }

  void _dispatchCmd(String ch) {
    switch (ch) {
      case 'a': add(PointForEvent(Team.blue)); break;
      case 'b': add(PointForEvent(Team.red));  break;
      case 'u': add(const UndoEvent());        break;
      case 'g': add(const NewGameEvent());     break;
      default:  break;
    }
  }

  // Optional helper
  void applyBleCommand(String cmd) => add(BleCommandEvent(cmd));

  // ========== team-wise undo ==========
  void _onUndoForTeam(UndoForTeamEvent e, Emitter<ScoringState> emit) {
    if (state.undoStack.isEmpty || _undoMeta.isEmpty) return;

    // Find the most recent action from that team
    int idx = _undoMeta.length - 1;
    while (idx >= 0 && _undoMeta[idx].team != e.team) {
      idx--;
    }
    if (idx < 0) return; // nothing from that team to undo

    // Jump undo to that index (inclusive)
    final target = state.undoStack[idx];
    final newUndo = state.undoStack.take(idx).toList();
    final skipped = state.undoStack.sublist(idx + 1); // states we jump over
    final newRedo = [...state.redoStack, ...skipped, state.match];

    emit(state.copyWith(
      match: target,
      undoStack: newUndo,
      redoStack: newRedo,
      lastActionLabel: 'Deshacer (${e.team == Team.blue ? 'A' : 'B'})',
    ));

    // Trim meta to match newUndo length
    _undoMeta.removeRange(idx, _undoMeta.length);
  }

  // Helper to deep-clone the match state (for undo/redo)
  MatchScore _clone(MatchScore m) =>
      m.copyWith(sets: m.sets.map((s) => s.copyWith()).toList());

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
}

class _ActionMeta {
  final Team? team;
  final String type;
  _ActionMeta(this.team, this.type);
}
