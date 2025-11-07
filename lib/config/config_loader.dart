import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'app_config.dart';

class ConfigLoader {
  static const String _defaultAsset = 'assets/config/padel_config.json';
  static const String _assetFromDefine = String.fromEnvironment('CONFIG_ASSET');

  static Future<AppConfig> load() async {
    try {
      final asset = _assetFromDefine.isNotEmpty ? _assetFromDefine : _defaultAsset;
      final raw = await rootBundle.loadString(asset);
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      // ▲ CRASH SAFETY: Si falla la carga del config, usar defaults
      print('[CONFIG] ⚠️ Error loading config: $e');
      print('[CONFIG] Stack trace: $st');
      print('[CONFIG] Using default configuration...');
      
      // Retornar configuración mínima funcional
      return AppConfig(
        availableTeams: [
          TeamDef(id: 'verde', displayName: 'Verde', colorHex: '#009900'),
          TeamDef(id: 'negro', displayName: 'Negro', colorHex: '#171717'),
        ],
        teams: [],
        rules: RulesConfig(
          setsToWin: 2,
          goldenPoint: false,
          tiebreakAtSixSix: true,
          startingServerId: 'team1',
        ),
        ui: UiConfig(),
        voice: VoiceConfig(),
      );
    }
  }
}
