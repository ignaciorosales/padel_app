// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scoring_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchSettingsImpl _$$MatchSettingsImplFromJson(Map<String, dynamic> json) =>
    _$MatchSettingsImpl(
      setsToWin: (json['setsToWin'] as num?)?.toInt() ?? 2,
      tieBreakAtGames: (json['tieBreakAtGames'] as num?)?.toInt() ?? 6,
      goldenPoint: json['goldenPoint'] as bool? ?? false,
      tieBreakTarget: (json['tieBreakTarget'] as num?)?.toInt() ?? 7,
    );

Map<String, dynamic> _$$MatchSettingsImplToJson(_$MatchSettingsImpl instance) =>
    <String, dynamic>{
      'setsToWin': instance.setsToWin,
      'tieBreakAtGames': instance.tieBreakAtGames,
      'goldenPoint': instance.goldenPoint,
      'tieBreakTarget': instance.tieBreakTarget,
    };

_$GamePointsImpl _$$GamePointsImplFromJson(Map<String, dynamic> json) =>
    _$GamePointsImpl(
      blue: (json['blue'] as num?)?.toInt() ?? 0,
      red: (json['red'] as num?)?.toInt() ?? 0,
      isTieBreak: json['isTieBreak'] as bool? ?? false,
    );

Map<String, dynamic> _$$GamePointsImplToJson(_$GamePointsImpl instance) =>
    <String, dynamic>{
      'blue': instance.blue,
      'red': instance.red,
      'isTieBreak': instance.isTieBreak,
    };

_$SetScoreImpl _$$SetScoreImplFromJson(
  Map<String, dynamic> json,
) => _$SetScoreImpl(
  blueGames: (json['blueGames'] as num?)?.toInt() ?? 0,
  redGames: (json['redGames'] as num?)?.toInt() ?? 0,
  currentGame:
      json['currentGame'] == null
          ? const GamePoints()
          : GamePoints.fromJson(json['currentGame'] as Map<String, dynamic>),
  tieBreakStarter: $enumDecodeNullable(_$TeamEnumMap, json['tieBreakStarter']),
  isSuperTieBreak: json['isSuperTieBreak'] as bool? ?? false,
);

Map<String, dynamic> _$$SetScoreImplToJson(_$SetScoreImpl instance) =>
    <String, dynamic>{
      'blueGames': instance.blueGames,
      'redGames': instance.redGames,
      'currentGame': instance.currentGame,
      'tieBreakStarter': _$TeamEnumMap[instance.tieBreakStarter],
      'isSuperTieBreak': instance.isSuperTieBreak,
    };

const _$TeamEnumMap = {Team.blue: 'blue', Team.red: 'red'};

_$MatchScoreImpl _$$MatchScoreImplFromJson(
  Map<String, dynamic> json,
) => _$MatchScoreImpl(
  sets:
      (json['sets'] as List<dynamic>?)
          ?.map((e) => SetScore.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SetScore>[],
  currentSetIndex: (json['currentSetIndex'] as num?)?.toInt() ?? 0,
  server: $enumDecodeNullable(_$TeamEnumMap, json['server']) ?? Team.blue,
  receiver: $enumDecodeNullable(_$TeamEnumMap, json['receiver']) ?? Team.red,
  blueName: json['blueName'] as String? ?? 'Azul',
  redName: json['redName'] as String? ?? 'Rojo',
  paused: json['paused'] as bool? ?? false,
  settings:
      json['settings'] == null
          ? const MatchSettings()
          : MatchSettings.fromJson(json['settings'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$MatchScoreImplToJson(_$MatchScoreImpl instance) =>
    <String, dynamic>{
      'sets': instance.sets.map((e) => e.toJson()).toList(),
      'currentSetIndex': instance.currentSetIndex,
      'server': _$TeamEnumMap[instance.server]!,
      'receiver': _$TeamEnumMap[instance.receiver]!,
      'blueName': instance.blueName,
      'redName': instance.redName,
      'paused': instance.paused,
      'settings': instance.settings.toJson(),
    };
