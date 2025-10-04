import 'package:flutter/material.dart';
import 'package:speech_to_text_min/features/widgets/set_score.dart';

/// Widget para mostrar el historial de sets en el centro
class SetHistoryCenter extends StatelessWidget {
  final List<SetScore> sets;
  final double fontSize;
  
  const SetHistoryCenter({
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
