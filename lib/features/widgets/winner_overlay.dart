import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';

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

        final isBlueWinner = state.matchWinner == Team.blue;
        final winnerColor = isBlueWinner 
            ? const Color(0xFF66A3FF) // Azul
            : const Color(0xFFFF5757); // Rojo
        
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
                  color: Colors.black.withOpacity(0.85),
                  child: Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Trofeo grande
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 120,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 20),
                          
                          // Nombre del ganador
                          Text(
                            state.matchWinnerName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              color: winnerColor,
                              letterSpacing: 2,
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: winnerColor.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Texto "GANADOR"
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [Colors.amber, Colors.white, Colors.amber],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              "¡GANADOR!",
                              style: TextStyle(
                                fontSize: 32, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 15),
                          
                          // Muestra el resultado del partido
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              state.lastAnnouncement.replaceAll('¡', '').replaceAll('!', ''),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Mensaje de reinicio
                          Text(
                            "El juego se reiniciará automáticamente en unos segundos...",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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
