import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// A scoreboard widget that mirrors the stylised layout shown in the
/// provided padel scoreboard image. It uses a digital font for the
/// point and set values and applies a bold diagonal split across the
/// background. To use this widget you must include a digital font (for
/// example `digital-7.ttf`) in your Flutter project and declare it in
/// your `pubspec.yaml`. Refer to the instructions in the documentation
/// below.
///
/// Example `pubspec.yaml` configuration:
/// ```yaml
/// flutter:
///   fonts:
///     - family: Digital7
///       fonts:
///         - asset: assets/fonts/digital-7.ttf
/// ```
///
/// Then set `fontFamily: 'Digital7'` in the styles below. If you choose
/// a different font family name, update the `fontFamily` fields
/// accordingly.
class DigitalScoreboard extends StatelessWidget {
  const DigitalScoreboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScoringBloc, ScoringState>(
      buildWhen: (previous, current) => previous.match != current.match,
      builder: (context, state) {
        final match = state.match;
        final currentSet = match.currentSet;
        final game = currentSet.currentGame;
        final rules = match.settings;

        // Map game points to their textual representations.
        String mapPoints(int us, int them) {
          if (game.isTieBreak) return '$us';
          if (us >= 3 && them >= 3) {
            if (us == them) return '40';
            if (us == them + 1) return 'AD';
          }
          const vals = ['0', '15', '30', '40'];
          return vals[math.min(us, 3)];
        }

        final bluePts = mapPoints(game.blue, game.red);
        final redPts = mapPoints(game.red, game.blue);

        // Collect finished set scores in chronological order.
        final finishedSets = <_FinishedSet>[];
        for (int i = 0; i < match.sets.length; i++) {
          if (i == match.currentSetIndex) continue;
          final s = match.sets[i];
          // Skip sets without any games for robustness.
          if (s.blueGames == 0 && s.redGames == 0) continue;
          finishedSets.add(_FinishedSet(s.blueGames, s.redGames));
        }

        // Theme colours. Adjust these constants to tweak the palette.
        const redLight = Color(0xFFFF5757);
        const redDark = Color(0xFF912430);
        const blueLight = Color(0xFF66A3FF);
        const blueDark = Color(0xFF0D2A4D);
        const textColor = Colors.white;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final topBarHeight = height * 0.12;
            final pointsHeight = height * 0.4;

            return Stack(
              children: [
                // Diagonal background using custom clippers.
                Positioned.fill(
                  child: Stack(
                    children: [
                      ClipPath(
                        clipper: _LeftDiagonalClipper(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [redLight, redDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      ClipPath(
                        clipper: _RightDiagonalClipper(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [blueLight, blueDark],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top bar with timer and match indicator. The digital font is
                // used here as well for consistency.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topBarHeight,
                  child: Container(
                    color: Colors.black.withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'PADEL SCORE',
                          style: TextStyle(
                            color: textColor.withOpacity(0.9),
                            fontSize: topBarHeight * 0.35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '00:00',
                          style: TextStyle(
                            color: redLight,
                            fontSize: topBarHeight * 0.55,
                            fontFamily: 'Digital7',
                          ),
                        ),
                        Text(
                          'MATCH ${match.currentSetIndex + 1} / ${match.sets.length}',
                          style: TextStyle(
                            color: textColor.withOpacity(0.9),
                            fontSize: topBarHeight * 0.3,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main body. Contains team labels, big point digits, set
                // scores and tie‑break/deuce indicators.
                Positioned(
                  top: topBarHeight,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Row(
                      children: [
                        // Left (Blue) team column.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RotatedBox(
                                quarterTurns: -1,
                                child: Text(
                                  'AZUL',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.85),
                                    fontSize: height * 0.05,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Big points using digital font.
                              _DigitalPoints(
                                text: bluePts,
                                height: pointsHeight,
                                color: redLight,
                              ),
                              const Spacer(),
                              // Finished set history for blue team.
                              if (finishedSets.isNotEmpty)
                                _SetHistoryRow(
                                  entries: finishedSets,
                                  isBlue: true,
                                  digitHeight: height * 0.06,
                                  color: textColor,
                                ),
                            ],
                          ),
                        ),
                        // Center column with separator and current set games.
                        Container(
                          width: width * 0.14,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 2,
                                height: pointsHeight,
                                color: textColor.withOpacity(0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'VS',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: height * 0.06,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _DigitalPoints(
                                    text: '${currentSet.blueGames}',
                                    height: height * 0.07,
                                    color: textColor,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.5),
                                        fontSize: height * 0.05,
                                      ),
                                    ),
                                  ),
                                  _DigitalPoints(
                                    text: '${currentSet.redGames}',
                                    height: height * 0.07,
                                    color: textColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right (Red) team column.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  'ROJO',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.85),
                                    fontSize: height * 0.05,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _DigitalPoints(
                                text: redPts,
                                height: pointsHeight,
                                color: blueLight,
                                alignRight: true,
                              ),
                              const Spacer(),
                              if (finishedSets.isNotEmpty)
                                _SetHistoryRow(
                                  entries: finishedSets,
                                  isBlue: false,
                                  digitHeight: height * 0.06,
                                  color: textColor,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tie‑break / deuce indicator at the bottom.
                Positioned(
                  bottom: height * 0.02,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _TieBreakOrDeuceIndicator(
                      isTieBreak: game.isTieBreak,
                      isSuperTieBreak: currentSet.isSuperTieBreak,
                      target: currentSet.isSuperTieBreak ? 10 : rules.tieBreakTarget,
                      isDeuce: !game.isTieBreak && game.blue >= 3 && game.red >= 3 && game.blue == game.red,
                      goldenPoint: rules.goldenPoint,
                      fontSize: height * 0.05,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Helper class to store finished set results.
class _FinishedSet {
  final int blue;
  final int red;
  const _FinishedSet(this.blue, this.red);
}

/// Draws a row of finished sets for either the blue or red side. The
/// [isBlue] flag determines which team’s scores are drawn first. Set
/// scores are separated by a vertical bar.
class _SetHistoryRow extends StatelessWidget {
  final List<_FinishedSet> entries;
  final bool isBlue;
  final double digitHeight;
  final Color color;
  const _SetHistoryRow({
    required this.entries,
    required this.isBlue,
    required this.digitHeight,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final list = isBlue
        ? entries
        : entries.map((e) => _FinishedSet(e.red, e.blue)).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < list.length; i++) ...[
          _DigitalPoints(text: '${list[i].blue}', height: digitHeight, color: color),
          const SizedBox(width: 4),
          _DigitalPoints(text: '${list[i].red}', height: digitHeight, color: color),
          if (i != list.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                '|',
                style: TextStyle(
                  color: color.withOpacity(0.5),
                  fontSize: digitHeight * 0.8,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Displays a string of digits using the digital font. If [alignRight] is
/// true the digits will align to the right edge of their container. A
/// colon or a string containing non‑digit characters is rendered using
/// the default font to avoid missing glyphs.
class _DigitalPoints extends StatelessWidget {
  final String text;
  final double height;
  final Color color;
  final bool alignRight;
  const _DigitalPoints({
    required this.text,
    required this.height,
    required this.color,
    this.alignRight = false,
  });
  @override
  Widget build(BuildContext context) {
    // Basic assumption: the digital font digits have an aspect ratio of
    // roughly 0.5. You might need to tweak this based on the actual
    // font you choose.
    final width = height * 0.6;
    final children = <Widget>[];
    final chars = text.split('');
    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];
      children.add(Container(
        width: width,
        alignment: Alignment.bottomLeft,
        child: Text(
          ch,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: height,
            fontFamily: 'Digital7',
            // Align baselines properly by setting height to 1.
            height: 1.0,
          ),
        ),
      ));
    }
    return Row(
      mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Widget that shows tie‑break or deuce information below the main
/// scoreboard. Colours are derived from the blue and red team colours.
class _TieBreakOrDeuceIndicator extends StatelessWidget {
  final bool isTieBreak;
  final bool isSuperTieBreak;
  final int target;
  final bool isDeuce;
  final bool goldenPoint;
  final double fontSize;
  const _TieBreakOrDeuceIndicator({
    required this.isTieBreak,
    required this.isSuperTieBreak,
    required this.target,
    required this.isDeuce,
    required this.goldenPoint,
    required this.fontSize,
  });
  @override
  Widget build(BuildContext context) {
    if (isTieBreak) {
      final label = isSuperTieBreak ? 'SUPER TIE‑BREAK' : 'TIE‑BREAK';
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
            TextSpan(
              text: ' A $target',
              style: TextStyle(
                color: Colors.orangeAccent.withOpacity(0.8),
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      );
    } else if (isDeuce) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DEUCE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
          if (goldenPoint) ...[
            const SizedBox(width: 8),
            Text(
              '· PUNTO DE ORO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Left diagonal clipper for background. Adjust the `cut` parameter to
/// change the slope of the diagonal separation.
class _LeftDiagonalClipper extends CustomClipper<Path> {
  final double cut;
  _LeftDiagonalClipper({this.cut = 0.5});
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * cut, 0);
    path.lineTo(size.width * (cut - 0.08), size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant _LeftDiagonalClipper oldClipper) {
    return oldClipper.cut != cut;
  }
}

/// Right diagonal clipper that complements the left clipper.
class _RightDiagonalClipper extends CustomClipper<Path> {
  final double cut;
  _RightDiagonalClipper({this.cut = 0.5});
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * cut, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * (cut - 0.08), size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant _RightDiagonalClipper oldClipper) {
    return oldClipper.cut != cut;
  }
}