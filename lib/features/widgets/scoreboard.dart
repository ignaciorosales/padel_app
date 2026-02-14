import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/set_score.dart';
import 'package:Puntazo/l10n/app_localizations.dart';

/// Helper to create darker color for gradient
Color _darkenColor(Color color, [double amount = 0.3]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Displays a string of digits using the digital font.
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
    final width = height * 0.6;
    final children = <Widget>[];
    final chars = text.split('');
    
    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];
      children.add(Container(
        width: width,
        alignment: alignRight ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Text(
          ch,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: height,
            fontFamily: 'Digital7',
            height: 1.0,
            shadows: [
              Shadow(
                offset: Offset(3, 3),
                blurRadius: 6,
                color: Colors.black.withOpacity(0.6),
              ),
            ],
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

/// Left diagonal clipper for background
class _LeftDiagonalClipper extends CustomClipper<Path> {
  final double topCut;
  final double bottomCut;
  _LeftDiagonalClipper({this.topCut = 0.6, this.bottomCut = 0.4});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * topCut, 0);
    path.lineTo(size.width * bottomCut, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(covariant _LeftDiagonalClipper oldClipper) {
    return oldClipper.topCut != topCut || oldClipper.bottomCut != bottomCut;
  }
}

/// Right diagonal clipper
class _RightDiagonalClipper extends CustomClipper<Path> {
  final double topCut;
  final double bottomCut;
  _RightDiagonalClipper({this.topCut = 0.6, this.bottomCut = 0.4});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * topCut, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * bottomCut, size.height);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(covariant _RightDiagonalClipper oldClipper) {
    return oldClipper.topCut != topCut || oldClipper.bottomCut != bottomCut;
  }
}

/// Hexagonal hive pattern painter for background depth
class _HexagonalHivePainter extends CustomPainter {
  final Color color;
  
  const _HexagonalHivePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const hexRadius = 40.0;
    final hexHeight = hexRadius * sqrt(3);
    const hexWidth = hexRadius * 2;

    final cols = (size.width / (hexWidth * 0.75)).ceil() + 2;
    final rows = (size.height / hexHeight).ceil() + 2;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final xOffset = col * hexWidth * 0.75;
        final yOffset = row * hexHeight + (col.isOdd ? hexHeight / 2 : 0);

        final path = _createHexagonPath(xOffset, yOffset, hexRadius);
        canvas.drawPath(path, paint);
      }
    }
  }

  Path _createHexagonPath(double x, double y, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final px = x + radius * cos(angle);
      final py = y + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexagonalHivePainter oldDelegate) => color != oldDelegate.color;
}

class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key});

  @override
  Widget build(BuildContext context) {
    final padelTheme = context.padelTheme;
    
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // ▲ OPTIMIZACIÓN CRÍTICA: Fondo estático con RepaintBoundary
          //   Este widget se dibuja UNA VEZ y NUNCA más se redibuja
          _StaticBackground(
            padelTheme: padelTheme,
            // ▲ FALLBACK: Colores hardcoded como backup
            blueColor: padelTheme.scoreboardBackgroundBlue,
            redColor: padelTheme.scoreboardBackgroundRed,
            hexColor: padelTheme.hexPatternColor,
          ),
          // Content
          _ScoreboardContent(),
        ],
      ),
    );
  }
}

/// Static background that never redraws
/// Uses RepaintBoundary for optimization
class _StaticBackground extends StatefulWidget {
  final PadelThemeExtension padelTheme;
  final Color blueColor;
  final Color redColor;
  final Color hexColor;

  const _StaticBackground({
    required this.padelTheme,
    required this.blueColor,
    required this.redColor,
    required this.hexColor,
  });

  @override
  State<_StaticBackground> createState() => _StaticBackgroundState();
}

class _StaticBackgroundState extends State<_StaticBackground> {
  @override
  Widget build(BuildContext context) {
    final blueGrad = widget.blueColor;
    final redGrad = widget.redColor;
    final hexCol = widget.hexColor;
    
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            // Left side (Team 1 gradient - color from config)
            ClipPath(
              clipper: _LeftDiagonalClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [blueGrad, _darkenColor(blueGrad)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Right side (Team 2 gradient - color from config)
            ClipPath(
              clipper: _RightDiagonalClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [redGrad, _darkenColor(redGrad)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            // Hexagonal hive pattern overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _HexagonalHivePainter(color: hexCol),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreboardContent extends StatelessWidget {
  const _ScoreboardContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: LayoutBuilder(
          builder: (_, c) {
            final h = c.maxHeight;
            final pointsSize = h * 0.34;
            final labelSize  = h * 0.06;
            final histFont   = h * 0.06;
            const textColor = Colors.white;

            return Stack(
              children: [
                // ====== Contenido central ======
                Column(
                  children: [
                    // Etiquetas de equipo + historial de sets (arriba)
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24, bottom: 12),
                      child: _TeamHeaderRow(
                        labelSize: labelSize,
                        histFont: histFont,
                        textColor: textColor,
                      ),
                    ),

                    // Puntos grandes (juego actual) - centrado verticalmente
                    Expanded(
                      child: Center(
                        child: _CurrentGamePointsRow(
                          pointsSize: pointsSize,
                          textColor: textColor,
                        ),
                      ),
                    ),

                    // Información de tie-break/punto de oro abajo
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _GameStatusIndicator(labelSize: labelSize),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ▲ OPTIMIZACIÓN: Row de encabezados con BlocSelector para minimizar rebuilds
///   Solo se reconstruye cuando cambia el servidor o los sets terminados
class _TeamHeaderRow extends StatelessWidget {
  final double labelSize;
  final double histFont;
  final Color textColor;

  const _TeamHeaderRow({
    required this.labelSize,
    required this.histFont,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ScoringBloc, ScoringState, _HeaderData>(
      selector: (state) {
        final m = state.match;
        final sets = m.sets;
        final curIdx = m.currentSetIndex;
        
        final finishedSets = <SetScore>[];
        
        // ========== TEST DATA - UNCOMMENT TO TEST ==========
        //  finishedSets.add(SetScore(6, 4));
        //  finishedSets.add(SetScore(4, 6));
        // ===================================================
        
        for (int i = 0; i < sets.length; i++) {
          if (i == curIdx) continue;
          final sb = sets[i].blueGames;
          final sr = sets[i].redGames;
          if (sb == sr) continue;
          finishedSets.add(SetScore(sb, sr));
        }
        
        return _HeaderData(m.server, finishedSets);
      },
      builder: (context, headerData) {
        final server = headerData.server;
        final finishedSets = headerData.finishedSets;
        
        return Row(
          children: [
            // VERDE (left side)
            Expanded(
              flex: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Indicador de saque
                  SizedBox(
                    width: labelSize * 0.9 + 8.0,
                    child: server == Team.blue
                        ? Image.asset(
                            'assets/images/padel_ball.png',
                            width: labelSize * 0.9,
                            height: labelSize * 0.9,
                            fit: BoxFit.contain,
                          )
                        : null,
                  ),
                  Builder(
                    builder: (ctx) {
                      final teamService = RepositoryProvider.of<TeamSelectionService>(ctx);
                      final team = teamService.getTeam1();
                      final teamName = team?.displayName.toUpperCase() ?? 'EQUIPO 1';
                      return Text(
                        teamName,
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: labelSize * 1.1,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'Digital7',
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Historial de sets en el centro
            Expanded(
              flex: 50,
              child: finishedSets.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SETS',
                        style: TextStyle(
                          color: textColor.withOpacity(0.5),
                          fontSize: histFont * 0.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < finishedSets.length; i++) ...[
                            Text(
                              '${finishedSets[i].blue}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: histFont * 1.2,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Digital7',
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                '-',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: histFont * 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${finishedSets[i].red}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: histFont * 1.2,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Digital7',
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            if (i != finishedSets.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  '|',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.4),
                                    fontSize: histFont * 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            ),
            
            // NEGRO (right side)
            Expanded(
              flex: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Builder(
                    builder: (ctx) {
                      final teamService = RepositoryProvider.of<TeamSelectionService>(ctx);
                      final team = teamService.getTeam2();
                      final teamName = team?.displayName.toUpperCase() ?? 'EQUIPO 2';
                      return Text(
                        teamName,
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: labelSize * 1.1,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'Digital7',
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Indicador de saque
                  SizedBox(
                    width: labelSize * 0.9 + 8.0,
                    child: server == Team.red
                        ? Image.asset(
                            'assets/images/padel_ball.png',
                            width: labelSize * 0.9,
                            height: labelSize * 0.9,
                            fit: BoxFit.contain,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ▲ OPTIMIZACIÓN: Row de puntos actuales con BlocSelector para cada lado
///   Solo se reconstruye el lado que cambió (azul o rojo)
class _CurrentGamePointsRow extends StatelessWidget {
  final double pointsSize;
  final Color textColor;

  const _CurrentGamePointsRow({
    required this.pointsSize,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Lado VERDE - 38% del espacio
        Expanded(
          flex: 38,
          child: Center(
            child: BlocSelector<ScoringBloc, ScoringState, String>(
              selector: (state) {
                final gp = state.match.currentSet.currentGame;
                
                // ▼ LÓGICA ORIGINAL DE PUNTUACIÓN (NO MODIFICADA)
                String mapPts(int us, int them) {
                  if (gp.isTieBreak) return '$us';
                  if (us >= 3 && them >= 3) {
                    if (us == them) return '40';
                    if (us == them + 1) return 'AD';
                  }
                  const L = ['0', '15', '30', '40'];
                  return L[min(us, 3)];
                }
                
                return mapPts(gp.blue, gp.red);
              },
              builder: (context, bluePts) {
                return _DigitalPoints(
                  text: bluePts,
                  height: pointsSize,
                  color: textColor,
                );
              },
            ),
          ),
        ),
        
        // Center - CURRENT SET
        Expanded(
          flex: 24,
          child: BlocSelector<ScoringBloc, ScoringState, _SetGamesData>(
            selector: (state) {
              final m = state.match;
              final s = m.currentSet;
              final gp = s.currentGame;
              final isSuperTB = m.currentSetIndex == 2 && m.settings.tbGames == 1 && gp.isTieBreak;
              return _SetGamesData(s.blueGames, s.redGames, isSuperTB);
            },
            builder: (context, setData) {
              return !setData.isSuperTB
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SET ACTUAL',
                            maxLines: 1,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: pointsSize * 0.12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withOpacity(0.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${setData.blueGames}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: pointsSize * 0.42,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Digital7',
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: pointsSize * 0.4),
                              Text(
                                '${setData.redGames}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: pointsSize * 0.42,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Digital7',
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink();
            },
          ),
        ),
        
        // Lado NEGRO - 38% del espacio
        Expanded(
          flex: 38,
          child: Center(
            child: BlocSelector<ScoringBloc, ScoringState, String>(
              selector: (state) {
                final gp = state.match.currentSet.currentGame;
                
                // ▼ LÓGICA ORIGINAL DE PUNTUACIÓN (NO MODIFICADA)
                String mapPts(int us, int them) {
                  if (gp.isTieBreak) return '$us';
                  if (us >= 3 && them >= 3) {
                    if (us == them) return '40';
                    if (us == them + 1) return 'AD';
                  }
                  const L = ['0', '15', '30', '40'];
                  return L[min(us, 3)];
                }
                
                return mapPts(gp.red, gp.blue);
              },
              builder: (context, redPts) {
                return _DigitalPoints(
                  text: redPts,
                  height: pointsSize,
                  color: textColor,
                  alignRight: true,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// ▲ OPTIMIZACIÓN: Indicador de estado del juego (tie-break, deuce, etc.)
///   Solo se reconstruye cuando cambia el estado del juego
class _GameStatusIndicator extends StatelessWidget {
  final double labelSize;

  const _GameStatusIndicator({required this.labelSize});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ScoringBloc, ScoringState, _GameStatus>(
      selector: (state) {
        final gp = state.match.currentSet.currentGame;
        final isSuperTB = state.match.currentSet.isSuperTieBreak;
        final goldenPoint = state.match.settings.goldenPoint;
        
        // ▼ OPTIMIZACIÓN: Solo incluir puntos si están en deuce (ambos >= 3)
        //   De lo contrario, los puntos individuales causan rebuilds innecesarios
        final isInDeuce = !gp.isTieBreak && gp.blue >= 3 && gp.red >= 3 && gp.blue == gp.red;
        
        return _GameStatus(
          gp.isTieBreak, 
          isSuperTB, 
          isInDeuce ? gp.blue : 0,
          isInDeuce ? gp.red : 0,
          goldenPoint
        );
      },
      builder: (context, status) {
        final l10n = AppLocalizations.of(context)!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status.isTieBreak)
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: status.isSuperTieBreak ? l10n.superTieBreak.toUpperCase() : l10n.tieBreak.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: labelSize * 0.8,
                        fontFamily: 'Digital7',
                      ),
                    ),
                    TextSpan(
                      text: ' A ${status.isSuperTieBreak ? 10 : 7}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelSize * 0.8,
                        fontFamily: 'Digital7',
                      ),
                    ),
                  ],
                ),
              )
            else if (!status.isTieBreak && status.blue >= 3 && status.red >= 3 && status.blue == status.red)
              Row(
                children: [
                  Text(
                    l10n.deuce.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: labelSize * 0.8,
                      fontFamily: 'Digital7',
                    ),
                  ),
                  if (status.goldenPoint) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· ${l10n.goldenPoint.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: labelSize * 0.8,
                        fontFamily: 'Digital7',
                      ),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

// ▲ OPTIMIZACIÓN: Clases de datos para comparación eficiente en BlocSelector
class _HeaderData {
  final Team server;
  final List<SetScore> finishedSets;

  _HeaderData(this.server, this.finishedSets);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeaderData &&
          runtimeType == other.runtimeType &&
          server == other.server &&
          _listsEqual(finishedSets, other.finishedSets);

  @override
  int get hashCode => server.hashCode ^ finishedSets.length.hashCode;

  bool _listsEqual(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].blue != b[i].blue || a[i].red != b[i].red) return false;
    }
    return true;
  }
}

class _SetGamesData {
  final int blueGames;
  final int redGames;
  final bool isSuperTB;

  _SetGamesData(this.blueGames, this.redGames, this.isSuperTB);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SetGamesData &&
          runtimeType == other.runtimeType &&
          blueGames == other.blueGames &&
          redGames == other.redGames &&
          isSuperTB == other.isSuperTB;

  @override
  int get hashCode => blueGames.hashCode ^ redGames.hashCode ^ isSuperTB.hashCode;
}

class _GameStatus {
  final bool isTieBreak;
  final bool isSuperTieBreak;
  final int blue;
  final int red;
  final bool goldenPoint;

  _GameStatus(this.isTieBreak, this.isSuperTieBreak, this.blue, this.red, this.goldenPoint);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GameStatus &&
          runtimeType == other.runtimeType &&
          isTieBreak == other.isTieBreak &&
          isSuperTieBreak == other.isSuperTieBreak &&
          blue == other.blue &&
          red == other.red &&
          goldenPoint == other.goldenPoint;

  @override
  int get hashCode =>
      isTieBreak.hashCode ^
      isSuperTieBreak.hashCode ^
      blue.hashCode ^
      red.hashCode ^
      goldenPoint.hashCode;
}

// ▲ ELIMINADO: _ClockWidget (consumía recursos innecesarios)
