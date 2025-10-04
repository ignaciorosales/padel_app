import 'package:flutter/material.dart';

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
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSuperTieBreak ? 10 : 8, 
        vertical: isSuperTieBreak ? 6 : 4
      ),
      decoration: isSuperTieBreak 
          ? BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFC107).withOpacity(0.5),
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
              color: const Color(0xFFFFC107),
            ),
          Text(
            isSuperTieBreak ? 'SUPER TIE-BREAK A $target' : 'TIE-BREAK A $target',
            style: TextStyle(
              color: isSuperTieBreak
                  ? Colors.white
                  : Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
          if (isSuperTieBreak)
            Icon(
              Icons.star_rate_rounded,
              size: fontSize * 0.9,
              color: const Color(0xFFFFC107),
            ),
        ],
      ),
    );
  }
}
