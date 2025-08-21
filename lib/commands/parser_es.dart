// lib/features/commands/parser_es.dart
import 'package:speech_to_text_min/commands/command.dart';
import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
class DynamicEsParser {
  final AppConfig cfg;
  DynamicEsParser(this.cfg);

  Team? _teamFrom(String s) {
    final t = s.toLowerCase().trim();
    final t1 = cfg.teams.isNotEmpty ? cfg.teams[0] : null;
    final t2 = cfg.teams.length > 1 ? cfg.teams[1] : null;

    bool hits(String needle, List<String> pool) =>
        pool.any((x) => needle.contains(x.toLowerCase()));

    if (t1 != null) {
      final pool = [t1.displayName.toLowerCase(), ...t1.synonyms];
      if (hits(t, pool)) return Team.blue; // team1
    }
    if (t2 != null) {
      final pool = [t2.displayName.toLowerCase(), ...t2.synonyms];
      if (hits(t, pool)) return Team.red; // team2
    }
    return null;
  }

  // Palabras -> indices internos de puntos (0,1,2,3,4=AD)
  static const _numWord = <String, int>{
    'cero': 0, '0': 0,
    'quince': 1, '15': 1,
    'treinta': 2, '30': 2,
    'cuarenta': 3, '40': 3,
    'adv': 4, 'ventaja': 4, 'ad': 4,
  };

  List<Command> parse(String raw) {
    final t = raw.toLowerCase().trim();
    final cmds = <Command>[];

    // ---- básicos
    if (RegExp(r'\bdeshacer\b').hasMatch(t)) cmds.add(const Command.undo());
    if (RegExp(r'\brehacer\b').hasMatch(t)) cmds.add(const Command.redo());
    if (RegExp(r'(nuevo|reiniciar)\s+partido').hasMatch(t)) cmds.add(const Command.newMatch());
    if (RegExp(r'\bnuevo\s+set\b').hasMatch(t)) cmds.add(const Command.newSet());
    if (RegExp(r'\bnuevo\s+juego\b').hasMatch(t)) cmds.add(const Command.newGame());

    // ---- punto para X  (soporta "punto para X" y "punto X")
    final rxPoint = RegExp(r'\b(punto|pt)\s+(?:para\s+)?(.+)$');
    final p = rxPoint.firstMatch(t);
    if (p != null) {
      final team = _teamFrom(p.group(2)!);
      if (team != null) cmds.add(Command.pointFor(team));
    }

    // ---- quitar/restar punto a X
    final rxRemove = RegExp(r'\b(quitar|restar)\s+punto\s+a\s+(.+)$');
    final q = rxRemove.firstMatch(t);
    if (q != null) {
      final team = _teamFrom(q.group(2)!);
      if (team != null) cmds.add(Command.removePoint(team));
    }

    // ---- forzar juego/set para X (evita chocar con "nuevo juego")
    final rxForceGame = RegExp(r'^(?:forzar\s+)?juego\s+(?:para\s+)?(.+)$');
    final fg = rxForceGame.firstMatch(t);
    if (fg != null && !RegExp(r'\bnuevo\s+juego\b').hasMatch(t)) {
      final team = _teamFrom(fg.group(1)!);
      if (team != null) cmds.add(Command.forceGameFor(team));
    }

    final rxForceSet = RegExp(r'^(?:forzar\s+)?set\s+(?:para\s+)?(.+)$');
    final fs = rxForceSet.firstMatch(t);
    if (fs != null && !RegExp(r'\bnuevo\s+set\b').hasMatch(t)) {
      final team = _teamFrom(fs.group(1)!);
      if (team != null) cmds.add(Command.forceSetFor(team));
    }

    // ---- “marcador 40 a 30” / “marcador 30-0”
    final m = RegExp(r'\bmarcador\s+([a-z0-9]+)\s*(?:-|a|:)\s*([a-z0-9]+)\b').firstMatch(t);
    if (m != null) {
      final b = _numWord[m.group(1)!];
      final r = _numWord[m.group(2)!];
      if (b != null && r != null) cmds.add(Command.setExplicitGamePoints(b, r));
    }

    // ❌ Servidor manual removido (se deduce automáticamente)
    // // final s = RegExp(r'(saca|saque)\s+(.+)$').firstMatch(t);
    // // if (s != null) { ... }

    // ---- reglas
    // if (RegExp(r'\bactivar\s+tiebreak\b').hasMatch(t)) {
    //   cmds.add(const Command.toggleTieBreakAtSixSix(true));
    // }
    // if (RegExp(r'\bdesactivar\s+tiebreak\b').hasMatch(t)) {
    //   cmds.add(const Command.toggleTieBreakAtSixSix(false));
    // }
    if (RegExp(r'\bactivar\s+punto\s+de\s+oro\b').hasMatch(t)) {
      cmds.add(const Command.toggleGoldenPoint(true));
    }
    if (RegExp(r'\bdesactivar\s+punto\s+de\s+oro\b').hasMatch(t)) {
      cmds.add(const Command.toggleGoldenPoint(false));
    }
    if (RegExp(r'\b(anuncia|dime|di)\s+marcador\b').hasMatch(t) ||
        RegExp(r'\bcu[aá]l\s+es\s+el\s+marcador\b').hasMatch(t)) {
      cmds.add(const Command.announceScore());
    }

    return cmds;
  }
}
