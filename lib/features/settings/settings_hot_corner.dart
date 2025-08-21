import 'package:flutter/material.dart';
import 'match_settings_sheet.dart';

class SettingsHotCorner extends StatelessWidget {
  const SettingsHotCorner({super.key});

  @override
  Widget build(BuildContext context) {
    // Área invisible; ajusta tamaño si querés hacerlo más “exigente”
    return Positioned(
      right: 0,
      top: 0,
      child: SizedBox(
        width: 64,
        height: 64,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => showMatchSettingsSheet(context),
          onDoubleTap: () => showMatchSettingsSheet(context),
        ),
      ),
    );
  }
}
