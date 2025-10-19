import 'package:flutter/material.dart';
import 'package:Puntazo/config/app_theme.dart';

/// Widget que muestra información sobre el tipo de tie-break en curso
class TieBreakIndicator extends StatelessWidget {
  final int target;
  final bool isSuper;
  final double fontSize;
  
  const TieBreakIndicator({
    required this.target,
    required this.isSuper,
    required this.fontSize,
  });
  
  @override
  Widget build(BuildContext context) {
    final isSuperTieBreak = isSuper;
    final padelTheme = context.padelTheme;
    final tieBreakColor = isSuperTieBreak 
        ? padelTheme.goldenPointColor 
        : padelTheme.tieBreakColor;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSuperTieBreak ? 10 : 8, 
        vertical: isSuperTieBreak ? 6 : 4
      ),
      decoration: isSuperTieBreak 
          ? BoxDecoration(
              color: tieBreakColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tieBreakColor.withOpacity(0.5),
                width: 1.5,
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSuperTieBreak) 
            Icon(
              Icons.star_rate_rounded,
              size: fontSize * 0.9,
              color: tieBreakColor,
            ),
          Text(
            isSuperTieBreak ? 'SUPER TIE-BREAK A $target' : 'TIE-BREAK A $target',
            style: TextStyle(
              color: isSuperTieBreak
                  ? Theme.of(context).colorScheme.onSurface
                  : tieBreakColor,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              fontFamily: 'Digital7',
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.3),
                ),
              ],
            ),
          ),
          if (isSuperTieBreak)
            Icon(
              Icons.star_rate_rounded,
              size: fontSize * 0.9,
              color: tieBreakColor,
            ),
        ],
      ),
    );
  }
}
