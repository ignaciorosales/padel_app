import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/scoreboard_font_cubit.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/set_score.dart';
import 'package:Puntazo/l10n/app_localizations.dart';

// Re-export Server and PlayerPosition from scoring_models
import 'package:Puntazo/features/models/scoring_models.dart' show Server, PlayerPosition;

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
    final teamService = RepositoryProvider.of<TeamSelectionService>(context);
    
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Fondo que reacciona al swap
          BlocSelector<ScoringBloc, ScoringState, bool>(
            selector: (state) => state.isSwapped,
            builder: (context, isSwapped) {
              // Obtener colores de los equipos seleccionados
              final leftColor = isSwapped ? teamService.getColor2() : teamService.getColor1();
              final rightColor = isSwapped ? teamService.getColor1() : teamService.getColor2();
              
              return _StaticBackground(
                padelTheme: padelTheme,
                leftColor: leftColor,
                rightColor: rightColor,
                hexColor: padelTheme.hexPatternColor,
              );
            },
          ),
          // Content
          _ScoreboardContent(),
        ],
      ),
    );
  }
}

/// Background that reacts to swap
class _StaticBackground extends StatelessWidget {
  final PadelThemeExtension padelTheme;
  final Color leftColor;
  final Color rightColor;
  final Color hexColor;

  const _StaticBackground({
    required this.padelTheme,
    required this.leftColor,
    required this.rightColor,
    required this.hexColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Left side gradient
          ClipPath(
            clipper: _LeftDiagonalClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [leftColor, _darkenColor(leftColor)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Right side gradient
          ClipPath(
            clipper: _RightDiagonalClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rightColor, _darkenColor(rightColor)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          // Hexagonal hive pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _HexagonalHivePainter(color: hexColor),
            ),
          ),
        ],
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
            // Escala de números del marcador (configurable en Ajustes).
            final scale = context.watch<ScoreboardFontCubit>().state.scale;
            // Tamaños aumentados para mejor visibilidad
            final pointsSize = h * 0.52 * scale;  // Puntos grandes del juego actual
            final labelSize  = h * 0.10;  // Etiquetas de equipo
            final histFont   = h * 0.10;  // Historial de sets
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
///   Solo se reconstruye cuando cambia el servidor, sets terminados o isSwapped
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
        
        for (int i = 0; i < sets.length; i++) {
          if (i == curIdx) continue;
          final sb = sets[i].blueGames;
          final sr = sets[i].redGames;
          if (sb == sr) continue;
          finishedSets.add(SetScore(sb, sr));
        }
        
        return _HeaderData(m.server, m.currentServer, finishedSets, state.isSwapped);
      },
      builder: (context, headerData) {
        final server = headerData.server;
        final currentServer = headerData.currentServer;
        final finishedSets = headerData.finishedSets;
        final isSwapped = headerData.isSwapped;
        final positionLabel = headerData.serverPositionLabel;
        
        return Row(
              children: [
                // VERDE (left side)
                Expanded(
                  flex: 25,
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Indicador de saque con posición del jugador (DRY/REV)
                  // Si isSwapped: izquierda = Team.red, derecha = Team.blue
                  SizedBox(
                    width: labelSize * 2.2 + 8.0,
                    child: server == (isSwapped ? Team.red : Team.blue)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/padel_ball.png',
                                width: labelSize * 1.1,
                                height: labelSize * 1.1,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                positionLabel,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.85),
                                  fontSize: labelSize * 0.7,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Digital7',
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  Builder(
                    builder: (ctx) {
                      final teamService = RepositoryProvider.of<TeamSelectionService>(ctx);
                      // Si isSwapped, el equipo de la izquierda es getTeam2() (original derecha)
                      final team = isSwapped ? teamService.getTeam2() : teamService.getTeam1();
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
                            // Si isSwapped, invertir: mostrar red a la izquierda, blue a la derecha
                            Text(
                              '${isSwapped ? finishedSets[i].red : finishedSets[i].blue}',
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
                              '${isSwapped ? finishedSets[i].blue : finishedSets[i].red}',
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
                      // Si isSwapped, el equipo de la derecha es getTeam1() (original izquierda)
                      final team = isSwapped ? teamService.getTeam1() : teamService.getTeam2();
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
                  // Indicador de saque con posición del jugador (DRY/REV)
                  // Si isSwapped: derecha = Team.blue, izquierda = Team.red
                  SizedBox(
                    width: labelSize * 2.2 + 8.0,
                    child: server == (isSwapped ? Team.blue : Team.red)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                positionLabel,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.85),
                                  fontSize: labelSize * 0.7,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Digital7',
                                ),
                              ),
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/images/padel_ball.png',
                                width: labelSize * 1.1,
                                height: labelSize * 1.1,
                                fit: BoxFit.contain,
                              ),
                            ],
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

/// ▲ OPTIMIZACIÓN: Row de puntos actuales con BlocSelector único
///   USA isSwapped del estado del bloc para invertir la visualización
class _CurrentGamePointsRow extends StatelessWidget {
  final double pointsSize;
  final Color textColor;

  const _CurrentGamePointsRow({
    required this.pointsSize,
    required this.textColor,
  });

  static String _mapPoints(int us, int them, bool isTieBreak) {
    if (isTieBreak) return '$us';
    if (us >= 3 && them >= 3) {
      if (us == them) return '40';
      if (us == them + 1) return 'AD';
    }
    const labels = ['0', '15', '30', '40'];
    return labels[min(us, 3)];
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ScoringBloc, ScoringState, _GamePointsData>(
      selector: (state) {
        final m = state.match;
        final s = m.currentSet;
        final gp = s.currentGame;
        final isSwapped = state.isSwapped;
        
        // Calcular puntos basados en si está swapped
        final leftPts = isSwapped ? gp.red : gp.blue;
        final rightPts = isSwapped ? gp.blue : gp.red;
        final leftGames = isSwapped ? s.redGames : s.blueGames;
        final rightGames = isSwapped ? s.blueGames : s.redGames;
        final isSuperTB = m.currentSetIndex == 2 && m.settings.tbGames == 1 && gp.isTieBreak;
        
        return _GamePointsData(
          leftPoints: _mapPoints(leftPts, rightPts, gp.isTieBreak),
          rightPoints: _mapPoints(rightPts, leftPts, gp.isTieBreak),
          leftGames: leftGames,
          rightGames: rightGames,
          isSuperTB: isSuperTB,
        );
      },
      builder: (context, data) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Lado IZQUIERDO - 38%
            Expanded(
              flex: 38,
              child: Center(
                child: Padding(
                  // Separa los puntos del bloque central de games.
                  padding: EdgeInsets.only(right: pointsSize * 0.22),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _DigitalPoints(
                      text: data.leftPoints,
                      height: pointsSize,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
            
            // Centro - SET ACTUAL - 24%
            Expanded(
              flex: 24,
              child: !data.isSuperTB
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // `letterSpacing` añade un espacio tras la última
                          // letra, desplazando visualmente el texto a la
                          // izquierda. Compensamos con un padding izquierdo del
                          // mismo tamaño para centrarlo sobre los games.
                          Padding(
                            padding: const EdgeInsets.only(left: 2.0),
                            child: Text(
                              'SET ACTUAL',
                              textAlign: TextAlign.center,
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
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${data.leftGames}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: pointsSize * 0.50,
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
                                '${data.rightGames}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: pointsSize * 0.50,
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
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            ),
            
            // Lado DERECHO - 38%
            Expanded(
              flex: 38,
              child: Center(
                child: Padding(
                  // Separa los puntos del bloque central de games.
                  padding: EdgeInsets.only(left: pointsSize * 0.22),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _DigitalPoints(
                      text: data.rightPoints,
                      height: pointsSize,
                      color: textColor,
                      alignRight: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
  final Server currentServer;  // Servidor actual con posición (DRY/REVÉS)
  final List<SetScore> finishedSets;
  final bool isSwapped;

  _HeaderData(this.server, this.currentServer, this.finishedSets, this.isSwapped);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeaderData &&
          runtimeType == other.runtimeType &&
          server == other.server &&
          currentServer == other.currentServer &&
          isSwapped == other.isSwapped &&
          _listsEqual(finishedSets, other.finishedSets);

  @override
  int get hashCode => server.hashCode ^ currentServer.hashCode ^ finishedSets.length.hashCode ^ isSwapped.hashCode;

  bool _listsEqual(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].blue != b[i].blue || a[i].red != b[i].red) return false;
    }
    return true;
  }
  
  /// Obtiene el nombre de la posición del servidor actual
  String get serverPositionLabel {
    return currentServer.position == PlayerPosition.drive ? 'DRY' : 'REV';
  }
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

/// Datos para los puntos y games del juego actual
class _GamePointsData {
  final String leftPoints;
  final String rightPoints;
  final int leftGames;
  final int rightGames;
  final bool isSuperTB;

  _GamePointsData({
    required this.leftPoints,
    required this.rightPoints,
    required this.leftGames,
    required this.rightGames,
    required this.isSuperTB,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GamePointsData &&
          runtimeType == other.runtimeType &&
          leftPoints == other.leftPoints &&
          rightPoints == other.rightPoints &&
          leftGames == other.leftGames &&
          rightGames == other.rightGames &&
          isSuperTB == other.isSuperTB;

  @override
  int get hashCode =>
      leftPoints.hashCode ^
      rightPoints.hashCode ^
      leftGames.hashCode ^
      rightGames.hashCode ^
      isSuperTB.hashCode;
}

// ▲ ELIMINADO: _ClockWidget (consumía recursos innecesarios)
