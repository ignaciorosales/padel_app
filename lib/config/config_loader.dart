import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'app_config.dart';

class ConfigLoader {
  static const String _defaultAsset = 'assets/config/padel_config.json';
  static const String _assetFromDefine = String.fromEnvironment('CONFIG_ASSET');

  static Future<AppConfig> load() async {
    final asset = _assetFromDefine.isNotEmpty ? _assetFromDefine : _defaultAsset;
    final raw = await rootBundle.loadString(asset);
    return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
