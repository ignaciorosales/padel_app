import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';

class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0D1117), Color(0xFF0B1222)]
              : [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: BlocBuilder<ScoringBloc, ScoringState>(
        buildWhen: (p, n) => p.match != n.match,
        builder: (context, state) {
          final m = state.match;
          final s = m.currentSet;
          final gp = s.currentGame;

          // Reglas
          final rules = m.settings;
          final bool goldenPoint = rules.goldenPoint;
          final int tieBreakTarget = rules.tieBreakTarget;

          // 40–40 / deuce
          final bool deuce = !gp.isTieBreak && gp.blue >= 3 && gp.red >= 3 && gp.blue == gp.red;

          // Mapeo de puntos del juego actual
          String mapPts(int us, int them) {
            if (gp.isTieBreak) return '$us';
            if (us >= 3 && them >= 3) {
              if (us == them) return '40';
              if (us == them + 1) return 'AD';
            }
            const L = ['0', '15', '30', '40'];
            return L[min(us, 3)];
          }

          final bluePts = mapPts(gp.blue, gp.red);
          final redPts  = mapPts(gp.red, gp.blue);

          // ====== Historial de sets cerrados (historial cronológico) ======
          final sets = m.sets;
          final curIdx = m.currentSetIndex;

          final finishedSets = <_SetScore>[];   // todos los sets completados (cronológicamente)
          
          // Ya no separamos por ganador, sino que mantenemos el orden cronológico
          for (int i = 0; i < sets.length; i++) {
            if (i == curIdx) continue; // omitimos el set en curso
            final sb = sets[i].blueGames;
            final sr = sets[i].redGames;
            if (sb == sr) continue; // por seguridad
            finishedSets.add(_SetScore(sb, sr)); // siempre como blue–red
          }

          // Colores de equipo
          const blueColor = Color(0xFF66A3FF);
          const redColor  = Color(0xFFFF5757);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: LayoutBuilder(
              builder: (_, c) {
                final h = c.maxHeight;
                final pointsSize = h * 0.34;
                final labelSize  = h * 0.06;
                final histFont   = h * 0.06; // tamaño de texto del historial (grande, sin chip)

                return Stack(
                  children: [
                    // ====== Contenido central ======
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Etiquetas de equipo + icono de servicio
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 2),
                          child: Row(
                            children: [
                              _TeamLabel(
                                label: 'AZUL',
                                color: blueColor,
                                isServer: m.server == Team.blue,
                                fontSize: labelSize,
                              ),
                              const Spacer(),
                              _TeamLabel(
                                label: 'ROJO',
                                color: redColor,
                                isServer: m.server == Team.red,
                                fontSize: labelSize,
                                alignRight: true,
                              ),
                            ],
                          ),
                        ),
                        
                        // Historial de sets completados (centrado)
                        if (finishedSets.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: _SetHistoryCenter(
                              sets: finishedSets,
                              fontSize: histFont * 0.8,
                            ),
                          ),

                              // Puntos grandes (juego actual)
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _BigPoints(text: bluePts, size: pointsSize, color: blueColor),
                              ),
                              
                              // Verificar si estamos en Super Tie-Break del 3er set
                              if (!(m.currentSetIndex == 2 && m.settings.tbGames == 1 && gp.isTieBreak)) 
                                // Set actual (mostrar solo si NO es Super Tie-Break)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'SET ACTUAL',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        fontSize: labelSize * 0.7,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          '${s.blueGames}',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontSize: pointsSize * 0.4,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          ' · ',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            fontSize: pointsSize * 0.3,
                                          ),
                                        ),
                                        Text(
                                          '${s.redGames}',
                                          style: TextStyle(
                                            color: redColor,
                                            fontSize: pointsSize * 0.4,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else 
                                // En Super Tie-Break, dejamos un espacio pero no mostramos el puntaje del set
                                const SizedBox(width: 80),
                              
                              Expanded(
                                child: _BigPoints(text: redPts, size: pointsSize, color: redColor, alignRight: true),
                              ),
                            ],
                          ),
                        ),                        // Añadimos información de tie-break/punto de oro abajo
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (gp.isTieBreak)
                                _TieBreakIndicator(
                                  target: rules.tieBreakTarget,
                                  isSuper: rules.tieBreakAtGames == 1 && m.currentSetIndex == 2,
                                  fontSize: labelSize * 0.8,
                                )
                              else if (!gp.isTieBreak && gp.blue >= 3 && gp.red >= 3 && gp.blue == gp.red)
                                Row(
                                  children: [
                                    Text(
                                      'DEUCE',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                        fontSize: labelSize * 0.8,
                                      ),
                                    ),
                                    if (rules.goldenPoint) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '· PUNTO DE ORO',
                                        style: TextStyle(
                                          color: const Color(0xFFFFC107).withOpacity(0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: labelSize * 0.8,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Widget para mostrar el historial de sets en el centro
class _SetHistoryCenter extends StatelessWidget {
  final List<_SetScore> sets;
  final double fontSize;
  
  const _SetHistoryCenter({
    required this.sets,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    // Colores de equipo (mismos que en Scoreboard)
    const blueColor = Color(0xFF66A3FF);
    const redColor = Color(0xFFFF5757);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SETS ANTERIORES',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: fontSize * 0.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        for (final s in sets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.blue}',
                  style: TextStyle(
                    color: blueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: fontSize * 0.7,
                  ),
                ),
                Text(
                  '${s.red}',
                  style: TextStyle(
                    color: redColor,
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SetScore {
  final int blue; // juegos de AZUL en ese set
  final int red;  // juegos de ROJO en ese set
  const _SetScore(this.blue, this.red);
}

class _TeamLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool isServer;
  final double fontSize;
  final bool alignRight;

  const _TeamLabel({
    required this.label,
    required this.color,
    required this.isServer,
    required this.fontSize,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.92),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isServer ? 1 : 0.16,
          child: Icon(Icons.sports_tennis, size: fontSize * 0.6, color: color),
        ),
      ],
    );
    return alignRight
        ? Row(mainAxisSize: MainAxisSize.min, children: row.children.reversed.toList())
        : row;
  }
}

class _BigPoints extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final bool alignRight;
  const _BigPoints({
    required this.text,
    required this.size,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: .9,
          letterSpacing: -2,
          shadows: [Shadow(blurRadius: 16, color: color.withOpacity(.55))],
        ),
      ),
    );
  }
}

/// Widget que muestra información sobre el tipo de tie-break en curso
class _TieBreakIndicator extends StatelessWidget {
  final int target;
  final bool isSuper;
  final double fontSize;
  
  const _TieBreakIndicator({
    required this.target,
    required this.isSuper,
    required this.fontSize,
  });
  
  @override
  Widget build(BuildContext context) {
    final isSuperTieBreak = isSuper;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSuperTieBreak ? 10 : 8, 
        vertical: isSuperTieBreak ? 6 : 4
      ),
      decoration: isSuperTieBreak 
          ? BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFC107).withOpacity(0.5),
                width: 1.5,
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSuperTieBreak) 
            Icon(
              Icons.star_rate_rounded,
              size: fontSize * 0.9,
              color: const Color(0xFFFFC107),
            ),
          Text(
            isSuperTieBreak ? 'SUPER TIE-BREAK A $target' : 'TIE-BREAK A $target',
            style: TextStyle(
              color: isSuperTieBreak
                  ? const Color(0xFFFFC107).withOpacity(0.9)
                  : Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
          if (isSuperTieBreak)
            Icon(
              Icons.star_rate_rounded,
              size: fontSize * 0.9,
              color: const Color(0xFFFFC107),
            ),
        ],
      ),
    );
  }
}
