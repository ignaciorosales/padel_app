// lib/features/widgets/scoreboard_optimized.dart
// ▲ OPTIMIZACIÓN RADICAL: CERO rebuilds innecesarios
// Cada número tiene su propio BlocSelector. Solo se actualiza lo que cambia.

import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart' hide SetScore;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/set_score.dart';

/// ▲ TELEMETRÍA UI: Singleton para rastrear rebuilds del scoreboard
class _UITelemetry {
  static final _UITelemetry _instance = _UITelemetry._internal();
  factory _UITelemetry() => _instance;
  _UITelemetry._internal();
  
  final List<_UIRebuildEvent> _events = [];
  int _blueDigitRebuilds = 0;
  int _redDigitRebuilds = 0;
  int _gamesRebuilds = 0;
  int _headerRebuilds = 0;
  
  void recordBlueDigitRebuild() {
    _blueDigitRebuilds++;
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    _events.add(_UIRebuildEvent('blue_digit', nowUs));
    if (kDebugMode) {
      debugPrint('[🎨 UI] Rebuild: Dígito AZUL (#$_blueDigitRebuilds)');
    }
  }
  
  void recordRedDigitRebuild() {
    _redDigitRebuilds++;
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    _events.add(_UIRebuildEvent('red_digit', nowUs));
    if (kDebugMode) {
      debugPrint('[🎨 UI] Rebuild: Dígito ROJO (#$_redDigitRebuilds)');
    }
  }
  
  void recordGamesRebuild() {
    _gamesRebuilds++;
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    _events.add(_UIRebuildEvent('games', nowUs));
    if (kDebugMode) {
      debugPrint('[🎨 UI] Rebuild: Juegos del set (#$_gamesRebuilds)');
    }
  }
  
  void recordHeaderRebuild() {
    _headerRebuilds++;
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    _events.add(_UIRebuildEvent('header', nowUs));
    if (kDebugMode) {
      debugPrint('[🎨 UI] Rebuild: Header (#$_headerRebuilds)');
    }
  }
  
  Map<String, int> getStats() {
    return {
      'blue_digit': _blueDigitRebuilds,
      'red_digit': _redDigitRebuilds,
      'games': _gamesRebuilds,
      'header': _headerRebuilds,
      'total': _blueDigitRebuilds + _redDigitRebuilds + _gamesRebuilds + _headerRebuilds,
    };
  }
  
  List<_UIRebuildEvent> getEvents() => List.unmodifiable(_events);
  
  void reset() {
    _blueDigitRebuilds = 0;
    _redDigitRebuilds = 0;
    _gamesRebuilds = 0;
    _headerRebuilds = 0;
    _events.clear();
  }
}

class _UIRebuildEvent {
  final String widget;
  final int timestampUs;
  
  _UIRebuildEvent(this.widget, this.timestampUs);
}

/// Helper para crear color más oscuro para gradiente
Color _darkenColor(Color color, [double amount = 0.3]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// ▲ OPTIMIZACIÓN: Widget de dígito individual que SOLO se actualiza cuando su valor cambia
class _DigitalDigit extends StatelessWidget {
  final String text;
  final double height;
  final Color color;
  final bool alignRight;
  final VoidCallback? onRebuild; // ▲ TELEMETRÍA: Callback cuando se reconstruye
  
  const _DigitalDigit({
    required this.text,
    required this.height,
    required this.color,
    this.alignRight = false,
    this.onRebuild,
  });
  
  @override
  Widget build(BuildContext context) {
    // ▲ TELEMETRÍA: Notificar rebuild
    onRebuild?.call();
    
    final width = height * 0.6;
    return Container(
      width: width,
      alignment: alignRight ? Alignment.bottomRight : Alignment.bottomLeft,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: height,
          fontFamily: 'Digital7',
          height: 1.0,
          shadows: [
            Shadow(
              offset: const Offset(3, 3),
              blurRadius: 6,
              color: Colors.black.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Left diagonal clipper for background
class _LeftDiagonalClipper extends CustomClipper<Path> {
  const _LeftDiagonalClipper();
  
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.6, 0);
    path.lineTo(size.width * 0.4, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(covariant _LeftDiagonalClipper oldClipper) => false;
}

/// Right diagonal clipper
class _RightDiagonalClipper extends CustomClipper<Path> {
  const _RightDiagonalClipper();
  
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.6, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * 0.4, size.height);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(covariant _RightDiagonalClipper oldClipper) => false;
}

/// ▲ OPTIMIZACIÓN: Fondo estático que NUNCA se reconstruye
class _StaticBackground extends StatelessWidget {
  const _StaticBackground();

  @override
  Widget build(BuildContext context) {
    final padelTheme = context.padelTheme;
    
    // RepaintBoundary: Flutter cachea este rendering y NUNCA lo vuelve a pintar
    return RepaintBoundary(
      child: Stack(
        children: [
          // Left side gradient
          ClipPath(
            clipper: const _LeftDiagonalClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    padelTheme.scoreboardBackgroundBlue,
                    _darkenColor(padelTheme.scoreboardBackgroundBlue),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Right side gradient
          ClipPath(
            clipper: const _RightDiagonalClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    padelTheme.scoreboardBackgroundRed,
                    _darkenColor(padelTheme.scoreboardBackgroundRed),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          // ▲ PATRÓN HEXAGONAL: Solo se dibuja UNA vez gracias a RepaintBoundary
          Positioned.fill(
            child: CustomPaint(
              painter: _HexagonalHivePainter(color: padelTheme.hexPatternColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hexagonal hive pattern painter (dentro de RepaintBoundary, se ejecuta UNA vez)
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

/// ▲ OPTIMIZACIÓN: Reloj separado que NO causa rebuilds del marcador
class _ClockWidget extends StatefulWidget {
  final double fontSize;
  
  const _ClockWidget({required this.fontSize});
  
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  String _timeString = '';
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final newTimeString = '$hour:$minute';
    
    if (_timeString != newTimeString) {
      setState(() {
        _timeString = newTimeString;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _timeString,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontFamily: 'Digital7',
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreboardOptimized extends StatelessWidget {
  const ScoreboardOptimized({super.key});
  
  /// ▲ TELEMETRÍA: Exponer stats de UI para el monitor BLE
  static Map<String, int> getUIStats() => _UITelemetry().getStats();
  static void resetUIStats() => _UITelemetry().reset();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // ▲ FONDO ESTÁTICO: Se dibuja UNA vez, NUNCA se reconstruye
        Positioned.fill(child: _StaticBackground()),
        // ▲ CONTENIDO DINÁMICO: Solo se actualizan los números que cambian
        _OptimizedScoreboardContent(),
      ],
    );
  }
}

class _OptimizedScoreboardContent extends StatelessWidget {
  const _OptimizedScoreboardContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: LayoutBuilder(
        builder: (_, c) {
          final h = c.maxHeight;
          final pointsSize = h * 0.34;
          final labelSize = h * 0.06;
          
          return Stack(
            children: [
              // ▲ RELOJ: Widget separado, NO causa rebuilds
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _ClockWidget(fontSize: labelSize * 1.2),
                ),
              ),
              
              // ▲ CONTENIDO PRINCIPAL
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header con nombres y sets cerrados (SOLO se actualiza si cambian sets)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 100, bottom: 12),
                    child: _TeamHeaderRow(labelSize: labelSize),
                  ),
                  
                  // ▲ PUNTOS DEL JUEGO ACTUAL: Cada dígito tiene su BlocSelector
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _CurrentGamePointsRow(pointsSize: pointsSize, labelSize: labelSize),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ▲ OPTIMIZACIÓN: Header que SOLO se actualiza cuando cambian sets o servidor
class _TeamHeaderRow extends StatelessWidget {
  final double labelSize;
  
  const _TeamHeaderRow({required this.labelSize});

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;
    
    return BlocSelector<ScoringBloc, ScoringState, _HeaderData>(
      selector: (state) => _HeaderData(
        server: state.match.server,
        finishedSets: _getFinishedSets(state.match),
      ),
      builder: (context, data) {
        // ▲ TELEMETRÍA: Registrar rebuild del header
        _UITelemetry().recordHeaderRebuild();
        
        return Row(
          children: [
            // TEAM 1 (left)
            Expanded(
              flex: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Indicador de saque
                  SizedBox(
                    width: labelSize * 0.9 + 8.0,
                    child: data.server == Team.blue
                        ? Image.asset(
                            'assets/images/padel_ball.png',
                            width: labelSize * 0.9,
                            height: labelSize * 0.9,
                            fit: BoxFit.contain,
                          )
                        : null,
                  ),
                  // Nombre del equipo (se lee UNA vez, no cambia)
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
                              offset: const Offset(1, 1),
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
            
            // HISTORIAL DE SETS (centro)
            Expanded(
              flex: 50,
              child: data.finishedSets.isNotEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < data.finishedSets.length; i++) ...[
                          Text(
                            '${data.finishedSets[i].blue}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: labelSize * 0.8,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Digital7',
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
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
                              fontSize: labelSize * 0.8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${data.finishedSets[i].red}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: labelSize * 0.8,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Digital7',
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                          if (i != data.finishedSets.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                '|',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: labelSize * 0.8,
                                ),
                              ),
                            ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            
            // TEAM 2 (right)
            Expanded(
              flex: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Nombre del equipo
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
                              offset: const Offset(1, 1),
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
                    child: data.server == Team.red
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

/// ▲ OPTIMIZACIÓN EXTREMA: Fila de puntos donde cada dígito tiene su BlocSelector
class _CurrentGamePointsRow extends StatelessWidget {
  final double pointsSize;
  final double labelSize;
  
  const _CurrentGamePointsRow({required this.pointsSize, required this.labelSize});

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LADO IZQUIERDO (Team Blue) - 40%
        Expanded(
          flex: 40,
          child: Center(
            // ▲ BlocSelector: SOLO se actualiza cuando cambian los puntos del equipo azul
            child: BlocSelector<ScoringBloc, ScoringState, String>(
              selector: (state) {
                final gp = state.match.currentSet.currentGame;
                if (gp.isTieBreak) return '${gp.blue}';
                if (gp.blue >= 3 && gp.red >= 3) {
                  if (gp.blue == gp.red) return '40';
                  if (gp.blue == gp.red + 1) return 'AD';
                }
                const pts = ['0', '15', '30', '40'];
                return pts[min(gp.blue, 3)];
              },
              builder: (context, bluePts) {
                return _DigitalDigit(
                  text: bluePts,
                  height: pointsSize,
                  color: textColor,
                  onRebuild: () => _UITelemetry().recordBlueDigitRebuild(), // ▲ TELEMETRÍA
                );
              },
            ),
          ),
        ),
        
        // CENTRO - Set actual (SOLO se actualiza cuando cambian juegos)
        Expanded(
          flex: 20,
          child: BlocSelector<ScoringBloc, ScoringState, _SetGamesData>(
            selector: (state) => _SetGamesData(
              blueGames: state.match.currentSet.blueGames,
              redGames: state.match.currentSet.redGames,
              isSuperTieBreak: state.match.currentSetIndex == 2 && 
                               state.match.settings.thirdSetFormat == 1 &&
                               state.match.currentSet.currentGame.isTieBreak,
            ),
            builder: (context, data) {
              // ▲ TELEMETRÍA: Registrar rebuild del juego
              _UITelemetry().recordGamesRebuild();
              
              if (data.isSuperTieBreak) {
                return const SizedBox.shrink(); // Ocultar en Super TB
              }
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 52),
                  const Text(
                    'SET ACTUAL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
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
                          '${data.blueGames}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: pointsSize * 0.25,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Digital7',
                          ),
                        ),
                      ),
                      Text(
                        '-',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: pointsSize * 0.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: pointsSize * 0.25,
                        child: Text(
                          '${data.redGames}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: pointsSize * 0.25,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Digital7',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        
        // LADO DERECHO (Team Red) - 40%
        Expanded(
          flex: 40,
          child: Center(
            // ▲ BlocSelector: SOLO se actualiza cuando cambian los puntos del equipo rojo
            child: BlocSelector<ScoringBloc, ScoringState, String>(
              selector: (state) {
                final gp = state.match.currentSet.currentGame;
                if (gp.isTieBreak) return '${gp.red}';
                if (gp.red >= 3 && gp.blue >= 3) {
                  if (gp.red == gp.blue) return '40';
                  if (gp.red == gp.blue + 1) return 'AD';
                }
                const pts = ['0', '15', '30', '40'];
                return pts[min(gp.red, 3)];
              },
              builder: (context, redPts) {
                return _DigitalDigit(
                  text: redPts,
                  height: pointsSize,
                  color: textColor,
                  alignRight: true,
                  onRebuild: () => _UITelemetry().recordRedDigitRebuild(), // ▲ TELEMETRÍA
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ========== DATA CLASSES (para BlocSelector) ==========

class _HeaderData {
  final Team server;
  final List<SetScore> finishedSets;
  
  _HeaderData({required this.server, required this.finishedSets});
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeaderData &&
          runtimeType == other.runtimeType &&
          server == other.server &&
          _listsEqual(finishedSets, other.finishedSets);

  @override
  int get hashCode => server.hashCode ^ finishedSets.hashCode;
}

class _SetGamesData {
  final int blueGames;
  final int redGames;
  final bool isSuperTieBreak;
  
  _SetGamesData({
    required this.blueGames,
    required this.redGames,
    required this.isSuperTieBreak,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SetGamesData &&
          runtimeType == other.runtimeType &&
          blueGames == other.blueGames &&
          redGames == other.redGames &&
          isSuperTieBreak == other.isSuperTieBreak;

  @override
  int get hashCode => blueGames.hashCode ^ redGames.hashCode ^ isSuperTieBreak.hashCode;
}

// Helper functions
List<SetScore> _getFinishedSets(MatchScore match) {
  final sets = match.sets;
  final curIdx = match.currentSetIndex;
  final finishedSets = <SetScore>[];
  
  for (int i = 0; i < sets.length; i++) {
    if (i == curIdx) continue;
    final sb = sets[i].blueGames;
    final sr = sets[i].redGames;
    if (sb == sr) continue;
    finishedSets.add(SetScore(sb, sr));
  }
  
  return finishedSets;
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
