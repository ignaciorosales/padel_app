import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/set_score.dart';

/// Displays a string of digits using the digital font. If [alignRight] is
/// true the digits will align to the right edge of their container.
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
    
    return Stack(
      children: [
        // Diagonal background with blue and red gradients
        Positioned.fill(
          child: Stack(
            children: [
              // Left side (Blue gradient for Blue team)
              ClipPath(
                clipper: _LeftDiagonalClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PadelColors.blueGradientStart, PadelColors.blueGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Right side (Red gradient for Red team)
              ClipPath(
                clipper: _RightDiagonalClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PadelColors.redGradientStart, PadelColors.redGradientEnd],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
              ),
              // Hexagonal hive pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _HexagonalHivePainter(color: padelTheme.hexPatternColor),
                ),
              ),
            ],
          ),
        ),
        // Content
        _ScoreboardContent(),
      ],
    );
  }
}

class _ScoreboardContent extends StatelessWidget {
  const _ScoreboardContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: BlocBuilder<ScoringBloc, ScoringState>(
        buildWhen: (p, n) => p.match != n.match,
        builder: (context, state) {
          final m = state.match;
          final s = m.currentSet;
          final gp = s.currentGame;

          // Reglas
          final rules = m.settings;

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

          final finishedSets = <SetScore>[];   // todos los sets completados (cronológicamente)
          
          // Ya no separamos por ganador, sino que mantenemos el orden cronológico
          for (int i = 0; i < sets.length; i++) {
            if (i == curIdx) continue; // omitimos el set en curso
            final sb = sets[i].blueGames;
            final sr = sets[i].redGames;
            if (sb == sr) continue; // por seguridad
            finishedSets.add(SetScore(sb, sr)); // siempre como blue–red
          }

          // All text will be white
          const textColor = Colors.white;

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
                    // ====== Brand at top center ======
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Puntazo.uy',
                            style: TextStyle(
                              color: textColor,
                              fontSize: labelSize * 1.2,
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
                          ),
                        ),
                      ),
                    ),
                    // ====== Contenido central ======
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Etiquetas de equipo + historial de sets (en una sola fila)
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 100.0, bottom: 12),
                          child: Row(
                            children: [
                              // AZUL (left side) - más hacia el borde
                              Expanded(
                                flex: 25,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // Indicador de saque hacia el borde izquierdo
                                    SizedBox(
                                      width: labelSize * 0.9 + 8.0,
                                      child: m.server == Team.blue
                                          ? Image.asset(
                                              'assets/images/padel_ball.png',
                                              width: labelSize * 0.9,
                                              height: labelSize * 0.9,
                                              fit: BoxFit.contain,
                                            )
                                          : null,
                                    ),
                                    Text(
                                      'AZUL',
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
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Historial de sets en el centro
                              Expanded(
                                flex: 50,
                                child: finishedSets.isNotEmpty
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        for (int i = 0; i < finishedSets.length; i++) ...[
                                        Text(
                                          '${finishedSets[i].blue}',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: histFont * 0.8,
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
                                        Text(
                                          '-',
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.7),
                                            fontSize: histFont * 0.8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${finishedSets[i].red}',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: histFont * 0.8,
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
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: Text(
                                              '|',
                                              style: TextStyle(
                                                color: textColor.withOpacity(0.5),
                                                fontSize: histFont * 0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                              ),
                              
                              // ROJO (right side) - más hacia el borde
                              Expanded(
                                flex: 25,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'ROJO',
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
                                    ),
                                    // Indicador de saque hacia el borde derecho
                                    SizedBox(
                                      width: labelSize * 0.9 + 8.0,
                                      child: m.server == Team.red
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
                          ),
                        ),
          
                              // Puntos grandes (juego actual)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Lado AZUL - 40% del espacio
                                Expanded(
                                  flex: 40,
                                  child: Center(
                                    child: _DigitalPoints(
                                      text: bluePts,
                                      height: pointsSize,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              
                              // Centro - SET ACTUAL en la diagonal (perfectamente centrado)
                              Expanded(
                                flex: 20,
                                child: !(m.currentSetIndex == 2 && m.settings.tbGames == 1 && gp.isTieBreak)
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 52,),
                                        // Etiqueta SET arriba como indicación
                                        Text(
                                          'SET ACTUAL',
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.6),
                                            fontSize: labelSize * 0.6,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.0,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(1, 1),
                                                blurRadius: 3,
                                                color: Colors.black.withOpacity(0.4),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Números del set centrados con ancho fijo
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: pointsSize * 0.25,
                                              child: Text(
                                                '${s.blueGames}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: pointsSize * 0.35,
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
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                              child: Text(
                                                '-',
                                                style: TextStyle(
                                                  color: textColor.withOpacity(0.5),
                                                  fontSize: pointsSize * 0.3,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: pointsSize * 0.25,
                                              child: Text(
                                                '${s.redGames}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: pointsSize * 0.35,
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
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                              ),
                              
                                // Lado ROJO - 40% del espacio
                                Expanded(
                                  flex: 40,
                                  child: Center(
                                    child: _DigitalPoints(
                                      text: redPts,
                                      height: pointsSize,
                                      color: textColor,
                                      alignRight: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),                        // Añadimos información de tie-break/punto de oro abajo
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (gp.isTieBreak)
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: m.currentSet.isSuperTieBreak ? 'SUPER TIE-BREAK' : 'TIE-BREAK',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: labelSize * 0.8,
                                          fontFamily: 'Digital7',
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' A ${m.currentSet.isSuperTieBreak ? 10 : 7}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: labelSize * 0.8,
                                          fontFamily: 'Digital7',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (!gp.isTieBreak && gp.blue >= 3 && gp.red >= 3 && gp.blue == gp.red)
                                Row(
                                  children: [
                                    Text(
                                      'DEUCE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: labelSize * 0.8,
                                        fontFamily: 'Digital7',
                                      ),
                                    ),
                                    if (rules.goldenPoint) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '· PUNTO DE ORO',
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

