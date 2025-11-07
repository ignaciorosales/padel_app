import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/set_score.dart';

/// ========== TELEMETRÍA UI ==========
/// Singleton para rastrear rebuilds de widgets del scoreboard
class _UITelemetry {
  static final _UITelemetry _instance = _UITelemetry._internal();
  factory _UITelemetry() => _instance;
  _UITelemetry._internal();

  int _bluePointsRebuilds = 0;
  int _redPointsRebuilds = 0;
  int _setGamesRebuilds = 0;
  int _headerRebuilds = 0;
  int _statusRebuilds = 0;
  int _backgroundRebuilds = 0; // ¡Esto DEBE ser 0 siempre!

  void recordBluePointsRebuild() {
    _bluePointsRebuilds++;
    if (kDebugMode) {
      print('🎨 UI] Rebuild: Puntos AZULES (#$_bluePointsRebuilds)');
    }
  }

  void recordRedPointsRebuild() {
    _redPointsRebuilds++;
    if (kDebugMode) {
      print('🎨 UI] Rebuild: Puntos ROJOS (#$_redPointsRebuilds)');
    }
  }

  void recordSetGamesRebuild() {
    _setGamesRebuilds++;
    if (kDebugMode) {
      print('🎨 UI] Rebuild: SET ACTUAL (#$_setGamesRebuilds)');
    }
  }

  void recordHeaderRebuild() {
    _headerRebuilds++;
    if (kDebugMode) {
      print('🎨 UI] Rebuild: HEADER (servidor/sets) (#$_headerRebuilds)');
    }
  }

  void recordStatusRebuild() {
    _statusRebuilds++;
    if (kDebugMode) {
      print('🎨 UI] Rebuild: STATUS (tie-break/deuce) (#$_statusRebuilds)');
    }
  }

  void recordBackgroundRebuild() {
    _backgroundRebuilds++;
    if (kDebugMode) {
      print('⚠️ UI] WARNING: FONDO se redibujó! (#$_backgroundRebuilds) - ¡ESTO NO DEBE PASAR!');
    }
  }

  Map<String, int> getStats() => {
    'blue_points': _bluePointsRebuilds,
    'red_points': _redPointsRebuilds,
    'set_games': _setGamesRebuilds,
    'header': _headerRebuilds,
    'status': _statusRebuilds,
    'background': _backgroundRebuilds, // DEBE ser 0
  };

  void reset() {
    _bluePointsRebuilds = 0;
    _redPointsRebuilds = 0;
    _setGamesRebuilds = 0;
    _headerRebuilds = 0;
    _statusRebuilds = 0;
    _backgroundRebuilds = 0;
    if (kDebugMode) {
      print('🔄 UI] Telemetría reseteada');
    }
  }
}
/// ========================================

/// Helper para crear color más oscuro para gradiente
Color _darkenColor(Color color, [double amount = 0.3]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

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

  // ▲ API pública para acceder a telemetría desde el monitor
  static Map<String, int> getUIStats() => _UITelemetry().getStats();
  static void resetUIStats() => _UITelemetry().reset();

  @override
  Widget build(BuildContext context) {
    final padelTheme = context.padelTheme;
    
    return Stack(
      children: [
        // ▲ OPTIMIZACIÓN CRÍTICA: Fondo estático con RepaintBoundary
        //   Este widget se dibuja UNA VEZ y NUNCA más se redibuja
        _StaticBackground(padelTheme: padelTheme),
        // Content
        _ScoreboardContent(),
      ],
    );
  }
}

/// ▲ OPTIMIZACIÓN: Fondo estático que NUNCA se redibuja
///   RepaintBoundary + StatelessWidget + const constructor = máxima eficiencia
class _StaticBackground extends StatelessWidget {
  final PadelThemeExtension padelTheme;

  const _StaticBackground({required this.padelTheme});

  @override
  Widget build(BuildContext context) {
    // Registrar telemetría (esto solo debe aparecer UNA VEZ en debug)
    if (kDebugMode) {
      _UITelemetry().recordBackgroundRebuild();
    }

    return RepaintBoundary(
      child: Positioned.fill(
        child: Stack(
          children: [
            // Left side (Team 1 gradient - color from config)
            ClipPath(
              clipper: _LeftDiagonalClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [padelTheme.scoreboardBackgroundBlue, _darkenColor(padelTheme.scoreboardBackgroundBlue)],
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
                    colors: [padelTheme.scoreboardBackgroundRed, _darkenColor(padelTheme.scoreboardBackgroundRed)],
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Etiquetas de equipo + historial de sets
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 100.0, bottom: 12),
                      child: _TeamHeaderRow(
                        labelSize: labelSize,
                        histFont: histFont,
                        textColor: textColor,
                      ),
                    ),

                    // Puntos grandes (juego actual)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: _CurrentGamePointsRow(
                          pointsSize: pointsSize,
                          textColor: textColor,
                        ),
                      ),
                    ),

                    // Información de tie-break/punto de oro abajo
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
    // ▲ TELEMETRÍA: Registrar rebuild del header
    _UITelemetry().recordHeaderRebuild();

    // ▲ OPTIMIZACIÓN: BlocSelector solo rebuilds cuando cambia server o sets
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
        // Lado VERDE - 40% del espacio
        Expanded(
          flex: 40,
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
                // ▲ TELEMETRÍA: Registrar rebuild de puntos azules
                _UITelemetry().recordBluePointsRebuild();

                return _DigitalPoints(
                  text: bluePts,
                  height: pointsSize,
                  color: textColor,
                );
              },
            ),
          ),
        ),
        
        // Centro - SET ACTUAL
        Expanded(
          flex: 20,
          child: BlocSelector<ScoringBloc, ScoringState, _SetGamesData>(
            selector: (state) {
              final m = state.match;
              final s = m.currentSet;
              final gp = s.currentGame;
              final isSuperTB = m.currentSetIndex == 2 && m.settings.tbGames == 1 && gp.isTieBreak;
              return _SetGamesData(s.blueGames, s.redGames, isSuperTB);
            },
            builder: (context, setData) {
              // ▲ TELEMETRÍA: Registrar rebuild del set actual
              _UITelemetry().recordSetGamesRebuild();

              return !setData.isSuperTB
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 52),
                      Text(
                        'SET ACTUAL',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: (pointsSize * 0.34) * 0.6,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: pointsSize * 0.25,
                            child: Text(
                              '${setData.blueGames}',
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
                              '${setData.redGames}',
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
                : const SizedBox.shrink();
            },
          ),
        ),
        
        // Lado NEGRO - 40% del espacio
        Expanded(
          flex: 40,
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
                // ▲ TELEMETRÍA: Registrar rebuild de puntos rojos
                _UITelemetry().recordRedPointsRebuild();

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
          isInDeuce ? gp.blue : 0,  // Solo pasar puntos si está en deuce
          isInDeuce ? gp.red : 0,   // De lo contrario, pasar 0 (no afecta rendering)
          goldenPoint
        );
      },
      builder: (context, status) {
        // ▲ TELEMETRÍA: Registrar rebuild del indicador de estado
        _UITelemetry().recordStatusRebuild();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status.isTieBreak)
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: status.isSuperTieBreak ? 'SUPER TIE-BREAK' : 'TIE-BREAK',
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
                    'DEUCE',
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
