import 'package:flutter/material.dart';

class TeamLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool isServer;
  final double fontSize;
  final bool alignRight;

  const TeamLabel({
    required this.label,
    required this.color,
    required this.isServer,
    required this.fontSize,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.92),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isServer ? 1 : 0.16,
          child: Icon(Icons.sports_tennis, size: fontSize * 0.6, color: color),
        ),
      ],
    );
    return alignRight
        ? Row(mainAxisSize: MainAxisSize.min, children: row.children.reversed.toList())
        : row;
  }
}
