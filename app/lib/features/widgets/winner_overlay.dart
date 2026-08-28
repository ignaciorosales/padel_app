import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// Muestra una pantalla completa de celebración cuando un equipo gana el partido
class WinnerOverlay extends StatefulWidget {
  const WinnerOverlay({super.key});

  @override
  State<WinnerOverlay> createState() => _WinnerOverlayState();
}

class _WinnerOverlayState extends State<WinnerOverlay> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScoringBloc, ScoringState>(
      listenWhen: (prev, current) => 
        prev.matchCompleted != current.matchCompleted && current.matchCompleted,
      listener: (context, state) {
        if (state.matchCompleted) {
          _controller.forward(from: 0.0);
        }
      },
      buildWhen: (prev, current) => 
        prev.matchCompleted != current.matchCompleted || 
        prev.matchWinner != current.matchWinner,
      builder: (context, state) {
        if (!state.matchCompleted || state.matchWinner == null) {
          return const SizedBox.shrink(); // No mostrar nada si no hay ganador
        }

        final teamService = context.read<TeamSelectionService>();
        final isBlueWinner = state.matchWinner == Team.blue;
        
        // Team.blue = getTeam1(), Team.red = getTeam2() (sin importar swap visual)
        final winnerColor = isBlueWinner 
            ? teamService.getColor1()
            : teamService.getColor2();
        final winnerName = isBlueWinner
            ? (teamService.getTeam1()?.displayName ?? 'Equipo 1')
            : (teamService.getTeam2()?.displayName ?? 'Equipo 2');
        
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        winnerColor,
                        Color.lerp(winnerColor, Colors.black, 0.5)!,
                      ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Tamaños proporcionales a la pantalla
                      final h = constraints.maxHeight;
                      final trophySize = h * 0.25;
                      final nameSize = h * 0.10;
                      final winnerSize = h * 0.08;
                      final spacing = h * 0.03;
                      
                      return Center(
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Trofeo dorado
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: trophySize,
                                  color: Colors.amber,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 20,
                                      offset: const Offset(4, 4),
                                    ),
                                  ],
                                ),
                                SizedBox(height: spacing),
                                
                                // Nombre del ganador - BLANCO con sombra
                                Text(
                                  winnerName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                    fontFamily: 'Digital7',
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.7),
                                        blurRadius: 8,
                                        offset: const Offset(3, 3),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                SizedBox(height: spacing * 0.5),
                                
                                // Texto "GANADOR" - dorado
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Colors.amber, Colors.white, Colors.amber],
                                    stops: [0.0, 0.5, 1.0],
                                  ).createShader(bounds),
                                  child: Text(
                                    "¡GANADOR!",
                                    style: TextStyle(
                                      fontSize: winnerSize, 
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 8,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 6,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }
}
