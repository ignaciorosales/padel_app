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
    return BlocBuilder<ScoringBloc, ScoringState>(
      builder: (context, state) {
        final m = state.match;
        final s = m.currentSet;
        final gp = s.currentGame;

        final bool deuce = !gp.isTieBreak &&
            gp.blue >= 3 &&
            gp.red >= 3 &&
            gp.blue == gp.red;

        String mapPts(int us, int them) {
          if (gp.isTieBreak) return '$us'; // numeric tie-break
          if (us >= 3 && them >= 3) {
            if (us == them) return '40'; // show 40–40, banner shows DEUCE
            if (us == them + 1) return 'AD';
          }
          const L = ['0', '15', '30', '40'];
          return L[min(us, 3)];
        }

        final bluePts = mapPts(gp.blue, gp.red);
        final redPts = mapPts(gp.red, gp.blue);

        return _ArenaPanel(
          leftTeam: m.blueName,
          rightTeam: m.redName,
          leftGames: s.blueGames,
          rightGames: s.redGames,
          leftPts: bluePts,
          rightPts: redPts,
          showDeuce: deuce && !gp.isTieBreak,
          isTieBreak: gp.isTieBreak,
          server: m.server,
        );
      },
    );
  }
}

class _ArenaPanel extends StatelessWidget {
  final String leftTeam, rightTeam;
  final int leftGames, rightGames;
  final String leftPts, rightPts;
  final bool showDeuce, isTieBreak;
  final Team server;

  const _ArenaPanel({
    required this.leftTeam,
    required this.rightTeam,
    required this.leftGames,
    required this.rightGames,
    required this.leftPts,
    required this.rightPts,
    required this.showDeuce,
    required this.isTieBreak,
    required this.server,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1117), Color(0xFF0B1222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Subtle vignette
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.transparent,
                  ],
                  center: Alignment.topLeft,
                  radius: 1.2,
                ),
              ),
            ),
            // Border + inner glow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white24, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: LayoutBuilder(
                builder: (context, c) {
                  // scale text nicely based on panel height
                  final h = c.maxHeight;
                  final smallPts = h * .24; // blue points top
                  final bigGames = h * .62; // red big numbers

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top row: names + blue points
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _TeamName(
                            name: leftTeam,
                            isServer: server == Team.blue,
                            alignRight: false,
                          ),
                          const Spacer(),
                          _BluePoints(text: leftPts, size: smallPts),
                          const SizedBox(width: 20),
                          _BluePoints(text: rightPts, size: smallPts),
                          const Spacer(),
                          _TeamName(
                            name: rightTeam,
                            isServer: server == Team.red,
                            alignRight: true,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom row: big games + center pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _BigRedNumber(
                              value: leftGames,
                              size: bigGames,
                              alignRight: false,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CenterPill(
                                label: isTieBreak ? 'TIE-BREAK' : 'SET',
                                color: isTieBreak
                                    ? cs.tertiary
                                    : cs.primary,
                              ),
                              const SizedBox(height: 8),
                              if (showDeuce)
                                _CenterPill(
                                  label: 'DEUCE',
                                  color: cs.secondary,
                                ),
                            ],
                          ),
                          Expanded(
                            child: _BigRedNumber(
                              value: rightGames,
                              size: bigGames,
                              alignRight: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  final String name;
  final bool isServer;
  final bool alignRight;

  const _TeamName({
    required this.name,
    required this.isServer,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isServer ? 1 : 0.18,
          child: const Icon(Icons.sports_tennis, size: 18, color: Colors.amber),
        ),
      ],
    );

    return alignRight
        ? Row(mainAxisSize: MainAxisSize.min, children: row.children!.reversed.toList())
        : row;
  }
}

class _BluePoints extends StatelessWidget {
  final String text;
  final double size;
  const _BluePoints({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF66A3FF),
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(blurRadius: 12, color: Color(0x802A7BFF)),
        ],
      ),
    );
  }
}

class _BigRedNumber extends StatelessWidget {
  final int value;
  final double size;
  final bool alignRight;
  const _BigRedNumber({
    required this.value,
    required this.size,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        value.toString().padLeft(2, '0'),
        style: TextStyle(
          color: const Color(0xFFFF5757),
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: .9,
          letterSpacing: -2,
          shadows: const [
            Shadow(blurRadius: 16, color: Color(0x80FF2D2D)),
          ],
        ),
      ),
    );
  }
}

class _CenterPill extends StatelessWidget {
  final String label;
  final Color color;
  const _CenterPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(.25), color.withOpacity(.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(.88),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
