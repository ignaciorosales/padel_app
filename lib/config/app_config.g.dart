// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamDefImpl _$$TeamDefImplFromJson(Map<String, dynamic> json) =>
    _$TeamDefImpl(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      synonyms:
          (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      colorHex: json['colorHex'] as String? ?? '#1E88E5',
    );

Map<String, dynamic> _$$TeamDefImplToJson(_$TeamDefImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'synonyms': instance.synonyms,
      'colorHex': instance.colorHex,
    };

_$RulesConfigImpl _$$RulesConfigImplFromJson(Map<String, dynamic> json) =>
    _$RulesConfigImpl(
      setsToWin: (json['setsToWin'] as num?)?.toInt() ?? 2,
      tiebreakAtSixSix: json['tiebreakAtSixSix'] as bool? ?? true,
      tiebreakTarget: (json['tiebreakTarget'] as num?)?.toInt() ?? 7,
      goldenPoint: json['goldenPoint'] as bool? ?? true,
      startingServerId: json['startingServerId'] as String? ?? 'team1',
    );

Map<String, dynamic> _$$RulesConfigImplToJson(_$RulesConfigImpl instance) =>
    <String, dynamic>{
      'setsToWin': instance.setsToWin,
      'tiebreakAtSixSix': instance.tiebreakAtSixSix,
      'tiebreakTarget': instance.tiebreakTarget,
      'goldenPoint': instance.goldenPoint,
      'startingServerId': instance.startingServerId,
    };

_$UiConfigImpl _$$UiConfigImplFromJson(Map<String, dynamic> json) =>
    _$UiConfigImpl(
      seedColorHex: json['seedColorHex'] as String? ?? '#0062FF',
      showGoldenPointChip: json['showGoldenPointChip'] as bool? ?? true,
    );

Map<String, dynamic> _$$UiConfigImplToJson(_$UiConfigImpl instance) =>
    <String, dynamic>{
      'seedColorHex': instance.seedColorHex,
      'showGoldenPointChip': instance.showGoldenPointChip,
    };

_$VoiceConfigImpl _$$VoiceConfigImplFromJson(Map<String, dynamic> json) =>
    _$VoiceConfigImpl(
      wakeWord: json['wakeWord'] as String? ?? 'marcador',
      language: json['language'] as String? ?? 'es-ES',
    );

Map<String, dynamic> _$$VoiceConfigImplToJson(_$VoiceConfigImpl instance) =>
    <String, dynamic>{
      'wakeWord': instance.wakeWord,
      'language': instance.language,
    };

_$AppConfigImpl _$$AppConfigImplFromJson(Map<String, dynamic> json) =>
    _$AppConfigImpl(
      ui:
          json['ui'] == null
              ? const UiConfig()
              : UiConfig.fromJson(json['ui'] as Map<String, dynamic>),
      teams:
          (json['teams'] as List<dynamic>?)
              ?.map((e) => TeamDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TeamDef>[],
      rules:
          json['rules'] == null
              ? const RulesConfig()
              : RulesConfig.fromJson(json['rules'] as Map<String, dynamic>),
      voice:
          json['voice'] == null
              ? const VoiceConfig()
              : VoiceConfig.fromJson(json['voice'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$AppConfigImplToJson(_$AppConfigImpl instance) =>
    <String, dynamic>{
      'ui': instance.ui,
      'teams': instance.teams,
      'rules': instance.rules,
      'voice': instance.voice,
    };
