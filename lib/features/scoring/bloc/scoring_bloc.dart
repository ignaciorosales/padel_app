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
    on<ToggleGoldenPointEvent>(_onToggleGoldenPoint);

    on<AnnounceScoreEvent>(_onAnnounceScore);

    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);

    // BLE command and team-wise undo handlers unchanged
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
    // Win by 2 games when at or above tieBreakAtGames
    if ((a >= tbGames || b >= tbGames) && (a - b).abs() >= 2) return true;
    // After a tie-break, one side will reach tbGames+1 (e.g. 7 in a 6–6 tie-break)
    if (a >= tbGames + 1 || b >= tbGames + 1) return true;
    return false;
  }

  int _setsWonBy(MatchScore m, Team t, MatchSettings settings) {
    var won = 0;
    for (final s in m.sets) {
      final a = s.blueGames, b = s.redGames;
      final tbGames = settings.tbGames;
      final over = ((a >= tbGames || b >= tbGames) && (a - b).abs() >= 2) ||
                   (a >= tbGames + 1 || b >= tbGames + 1);
      if (!over) continue;
      if ((t == Team.blue && a > b) || (t == Team.red && b > a)) won++;
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
    return m.copyWith(sets: newSets, currentSetIndex: newSets.length - 1);
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
      final nr = gp.red + (e.team == Team.red ? 1 : 0);

      final starter = set.tieBreakStarter ?? m.server;
      final tgt     = m.settings.tbTarget;
      final tbClosed = (nb >= tgt || nr >= tgt) && (nb - nr).abs() >= 2;

      if (tbClosed) {
        final winnerIsBlue = nb > nr;
        set = set.copyWith(
          blueGames: winnerIsBlue ? set.blueGames + 1 : set.blueGames,
          redGames: winnerIsBlue ? set.redGames : set.redGames + 1,
          currentGame: const GamePoints(),
          tieBreakStarter: null,
        );
        final nextServer = _other(starter);
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          server: nextServer,
          receiver: _other(nextServer),
        );
        m = _maybeAdvanceSet(m);
        skipGenericToggle = true;
      } else {
        final total      = nb + nr;
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
      if (set.blueGames == tbGames && set.redGames == tbGames && !set.currentGame.isTieBreak) {
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
    final settings = state.match.settings.withTbGames(e.games);
    _pushHistory(
      emit,
      state.match.copyWith(settings: settings),
      'Tie-break a ${e.games} juegos',
    );
  }

  void _onToggleGoldenPoint(ToggleGoldenPointEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    _pushHistory(
      emit,
      m.copyWith(settings: m.settings.withGoldenPoint(e.enabled)),
      'Punto de oro: ${e.enabled ? 'ON' : 'OFF'}',
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
    final prev = state.undoStack.last;
    emit(state.copyWith(
      match: prev,
      undoStack: state.undoStack.take(state.undoStack.length - 1).toList(),
      redoStack: [...state.redoStack, state.match],
      lastActionLabel: 'Deshacer',
    ));
    if (_undoMeta.isNotEmpty) _undoMeta.removeLast();
  }

  void _onRedo(RedoEvent e, Emitter<ScoringState> emit) {
    if (state.redoStack.isEmpty) return;
    final next = state.redoStack.last;
    emit(state.copyWith(
      match: next,
      redoStack: state.redoStack.take(state.redoStack.length - 1).toList(),
      undoStack: [...state.undoStack, state.match],
      lastActionLabel: 'Rehacer',
    ));
    // Push placeholder meta so lengths match (we don't know which team originally)
    _undoMeta.add(_ActionMeta(null, 'redo'));
  }

  // ========== BLE bridge ==========
  void _onBleCommand(BleCommandEvent e, Emitter<ScoringState> emit) {
    final cmd = e.cmd.trim().toLowerCase();
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
      case 'a':
        add(PointForEvent(_teamA));
        break;
      case 'b':
        add(PointForEvent(_teamB));
        break;
      case 'u':
        add(const UndoEvent());
        break;
      // Optional team-wise undo over BLE: send 'ua' or 'ub'
      case 'x': // placeholder, never hit; fallthrough shows 'ua'/'ub' idea
        break;
    }
  }

  // Optional helper if you prefer calling a method (e.g., from a listener)
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
