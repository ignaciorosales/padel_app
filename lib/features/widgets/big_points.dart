import 'package:flutter/material.dart';

class BigPointsWidget extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final bool alignRight;
  const BigPointsWidget({
    required this.text,
    required this.size,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: .9,
          letterSpacing: -2,
          shadows: [Shadow(blurRadius: 16, color: color.withOpacity(.55))],
        ),
      ),
    );
  }
}

