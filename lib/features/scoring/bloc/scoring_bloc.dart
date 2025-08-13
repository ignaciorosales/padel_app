import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'scoring_event.dart';
import 'scoring_state.dart';

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

    // ❌ fuera: swap, setServer, enter/exit TB
    on<ToggleTieRuleEvent>(_onToggleTieRule);
    on<ToggleGoldenPointEvent>(_onToggleGoldenPoint);

    on<AnnounceScoreEvent>(_onAnnounceScore);

    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
  }

  // ---------- helpers ----------
  void _pushHistory(Emitter<ScoringState> emit, MatchScore next, String label) {
    emit(state.copyWith(
      undoStack: [...state.undoStack, state.match],
      redoStack: const [],
      match: next,
      lastActionLabel: label,
    ));
  }

  MatchScore _clone(MatchScore m) =>
      m.copyWith(sets: m.sets.map((s) => s.copyWith()).toList());

  bool _gameClosed(SetScore before, SetScore after) {
    final pointsReset = after.currentGame.blue == 0 && after.currentGame.red == 0;
    final gameInc = after.blueGames != before.blueGames || after.redGames != before.redGames;
    return pointsReset && gameInc;
  }

  Team _other(Team t) => t == Team.blue ? Team.red : Team.blue;

  // 1–2–2–2 patrón TB (total = puntos ya jugados)
  Team _tbNextServer(Team starter, int total) {
    if (total == 0) return starter;
    final block = ((total - 1) ~/ 2) % 2; // 0 => oponente, 1 => starter
    return block == 0 ? _other(starter) : starter;
  }

  MatchScore _toggleServer(MatchScore m) {
    final nextServer = _other(m.server);
    return m.copyWith(
      server: nextServer,
      receiver: _other(nextServer),
    );
  }

  bool _isSetOver(SetScore s) {
    final a = s.blueGames, b = s.redGames;
    if ((a >= 6 || b >= 6) && (a - b).abs() >= 2) return true;
    if (a == 7 || b == 7) return true; // 7-x tras TB
    return false;
  }

  int _setsWonBy(MatchScore m, Team t) {
    var won = 0;
    for (final s in m.sets) {
      final a = s.blueGames, b = s.redGames;
      final over = ((a >= 6 || b >= 6) && (a - b).abs() >= 2) || (a == 7 || b == 7);
      if (!over) continue;
      if ((t == Team.blue && a > b) || (t == Team.red && b > a)) won++;
    }
    return won;
  }

  MatchScore _maybeAdvanceSet(MatchScore m) {
    final s = m.sets[m.currentSetIndex];
    if (!_isSetOver(s)) return m;

    final blueSets = _setsWonBy(m, Team.blue);
    final redSets = _setsWonBy(m, Team.red);
    final needs = m.settings.setsToWin;

    final matchOver = (blueSets >= needs || redSets >= needs);
    if (matchOver) return m;

    final newSets = [...m.sets, const SetScore()];
    return m.copyWith(sets: newSets, currentSetIndex: newSets.length - 1);
  }

  // ---------- handlers ----------
  void _onNewMatch(NewMatchEvent e, Emitter<ScoringState> emit) {
    final settings = e.settings ?? state.match.settings;
    final start = e.startingServer ?? Team.blue; // por defecto team1

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
    final idx = m.currentSetIndex;
    final before = m.sets[idx];
    var set = before;

    var skipGenericToggle = false; // 👈 evita doble toggle en cierre de TB

    if (set.currentGame.isTieBreak) {
      final gp = set.currentGame;
      final nb = gp.blue + (e.team == Team.blue ? 1 : 0);
      final nr = gp.red + (e.team == Team.red ? 1 : 0);

      final starter = set.tieBreakStarter ?? m.server;
      final tgt = m.settings.tieBreakTarget;
      final tbClosed = (nb >= tgt || nr >= tgt) && (nb - nr).abs() >= 2;

      if (tbClosed) {
        final winnerIsBlue = nb > nr;
        set = set.copyWith(
          blueGames: winnerIsBlue ? set.blueGames + 1 : set.blueGames,
          redGames: winnerIsBlue ? set.redGames : set.redGames + 1,
          currentGame: const GamePoints(),
          tieBreakStarter: null,
        );

        // El primer juego después del TB lo saca el OPONENTE del starter
        final nextServer = _other(starter);
        m = m.copyWith(
          sets: (m.sets.toList()..[idx] = set),
          server: nextServer,
          receiver: _other(nextServer),
        );

        m = _maybeAdvanceSet(m);
        skipGenericToggle = true; // ya fijamos server nosotros
      } else {
        final total = nb + nr; // puntos jugados tras este punto
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
      // Juego estándar (con o sin punto de oro)
      set = _advanceStandardPoint(set, e.team, m.settings.goldenPoint);

      // Entrar TB automático
      if (m.settings.tieBreakAtSixSix &&
          set.blueGames == 6 &&
          set.redGames == 6 &&
          !set.currentGame.isTieBreak) {
        set = set.copyWith(
          currentGame: const GamePoints(isTieBreak: true),
          tieBreakStarter: m.server, // guarda quién empieza el TB
        );
      }

      m = m.copyWith(sets: (m.sets.toList()..[idx] = set));
    }

    // Si se cerró un juego estándar, alterno saque y quizá avanzo set
    if (!skipGenericToggle && _gameClosed(before, set)) {
      m = _toggleServer(m);
      m = _maybeAdvanceSet(m);
    }

    final teamName = e.team == Team.blue ? state.match.blueName : state.match.redName;
    _pushHistory(emit, m, 'Punto $teamName');
  }

  SetScore _advanceStandardPoint(SetScore set, Team team, bool goldenPoint) {
    final gp = set.currentGame;
    int b = gp.blue, r = gp.red;

    if (goldenPoint) {
      if (team == Team.blue) b++; else r++;
      if (b >= 4 && r <= 3) {
        return set.copyWith(blueGames: set.blueGames + 1, currentGame: const GamePoints());
      }
      if (r >= 4 && b <= 3) {
        return set.copyWith(redGames: set.redGames + 1, currentGame: const GamePoints());
      }
      if (b == 4 && r == 3) {
        return set.copyWith(blueGames: set.blueGames + 1, currentGame: const GamePoints());
      }
      if (r == 4 && b == 3) {
        return set.copyWith(redGames: set.redGames + 1, currentGame: const GamePoints());
      }
      return set.copyWith(currentGame: gp.copyWith(blue: b, red: r));
    } else {
      if (team == Team.blue) b++; else r++;
      bool blueWins = false, redWins = false;

      if (b >= 4 && r <= 2) blueWins = true;
      if (r >= 4 && b <= 2) redWins = true;

      if (b >= 4 && r >= 4) {
        if ((b - r) >= 2) blueWins = true;
        if ((r - b) >= 2) redWins = true;
      }

      if (blueWins) {
        return set.copyWith(blueGames: set.blueGames + 1, currentGame: const GamePoints());
      }
      if (redWins) {
        return set.copyWith(redGames: set.redGames + 1, currentGame: const GamePoints());
      }
      return set.copyWith(currentGame: gp.copyWith(blue: b, red: r));
    }
  }

  void _onRemovePoint(RemovePointEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    final idx = m.currentSetIndex;
    final gp = m.sets[idx].currentGame;
    final nb = e.team == Team.blue ? (gp.blue > 0 ? gp.blue - 1 : 0) : gp.blue;
    final nr = e.team == Team.red ? (gp.red > 0 ? gp.red - 1 : 0) : gp.red;
    final updatedSet = m.sets[idx].copyWith(currentGame: gp.copyWith(blue: nb, red: nr));
    final sets = m.sets.toList()..[idx] = updatedSet;
    final teamName = e.team == Team.blue ? state.match.blueName : state.match.redName;
    _pushHistory(emit, m.copyWith(sets: sets), 'Quitar punto $teamName');
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
    _pushHistory(emit, m, 'Juego forzado');
  }

  void _onForceSetFor(ForceSetForEvent e, Emitter<ScoringState> emit) {
    var m = _clone(state.match);
    final updated = m.sets.toList();
    final idx = m.currentSetIndex;
    final set = updated[idx];
    updated[idx] = set.copyWith(
      blueGames: e.team == Team.blue ? (set.blueGames >= 6 ? set.blueGames : 6) : set.blueGames,
      redGames: e.team == Team.red ? (set.redGames >= 6 ? set.redGames : 6) : set.redGames,
      currentGame: const GamePoints(),
    );
    m = m.copyWith(sets: updated);
    m = _maybeAdvanceSet(m);
    _pushHistory(emit, m, 'Set forzado');
  }

  void _onSetExplicitGamePoints(SetExplicitGamePointsEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    final idx = m.currentSetIndex;
    final updated = m.sets[idx].copyWith(currentGame: GamePoints(blue: e.blue, red: e.red));
    final sets = m.sets.toList()..[idx] = updated;
    _pushHistory(emit, m.copyWith(sets: sets), 'Fijar puntos de juego');
  }

  void _onToggleTieRule(ToggleTieRuleEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    _pushHistory(emit, m.copyWith(settings: m.settings.copyWith(tieBreakAtSixSix: e.enabled)),
        'Tiebreak a 6–6: ${e.enabled ? 'ON' : 'OFF'}');
  }

  void _onToggleGoldenPoint(ToggleGoldenPointEvent e, Emitter<ScoringState> emit) {
    final m = _clone(state.match);
    _pushHistory(emit, m.copyWith(settings: m.settings.copyWith(goldenPoint: e.enabled)),
        'Punto de oro: ${e.enabled ? 'ON' : 'OFF'}');
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
  }
}
