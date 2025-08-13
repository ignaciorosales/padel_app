import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config.freezed.dart';
part 'app_config.g.dart';

@freezed
class TeamDef with _$TeamDef {
  const factory TeamDef({
    required String id,
    required String displayName,
    @Default([]) List<String> synonyms,
    @Default('#1E88E5') String colorHex,
  }) = _TeamDef;

  factory TeamDef.fromJson(Map<String, dynamic> json) => _$TeamDefFromJson(json);
}

@freezed
class RulesConfig with _$RulesConfig {
  const factory RulesConfig({
    @Default(2) int setsToWin,
    @Default(true) bool tiebreakAtSixSix,
    @Default(7) int tiebreakTarget,
    @Default(true) bool goldenPoint,
    @Default('team1') String startingServerId,
  }) = _RulesConfig;

  factory RulesConfig.fromJson(Map<String, dynamic> json) => _$RulesConfigFromJson(json);
}

@freezed
class UiConfig with _$UiConfig {
  const factory UiConfig({
    @Default('#0062FF') String seedColorHex,
    @Default(true) bool showGoldenPointChip,
  }) = _UiConfig;

  factory UiConfig.fromJson(Map<String, dynamic> json) => _$UiConfigFromJson(json);
}

@freezed
class VoiceConfig with _$VoiceConfig {
  const factory VoiceConfig({
    @Default('marcador') String wakeWord,
    @Default('es-ES') String language,
  }) = _VoiceConfig;

  factory VoiceConfig.fromJson(Map<String, dynamic> json) => _$VoiceConfigFromJson(json);
}

@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(UiConfig()) UiConfig ui,
    @Default(<TeamDef>[]) List<TeamDef> teams,     // orden = team1, team2
    @Default(RulesConfig()) RulesConfig rules,
    @Default(VoiceConfig()) VoiceConfig voice,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
}

extension AppConfigX on AppConfig {
  Color get seedColor => _hex(seedColorHexOrDefault(ui.seedColorHex));

  Color colorFor(String teamId) {
    final t = teams.firstWhere(
      (x) => x.id == teamId,
      orElse: () => teams.isNotEmpty ? teams.first : const TeamDef(id: 'team1', displayName: 'Equipo 1'),
    );
    return _hex(seedColorHexOrDefault(t.colorHex));
  }

  static String seedColorHexOrDefault(String s) => (s.isEmpty ? '#0062FF' : s);
}

Color _hex(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFF0062FF;
  return Color(v);
}
