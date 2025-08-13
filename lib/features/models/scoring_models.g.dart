// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scoring_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchSettingsImplImpl _$$MatchSettingsImplImplFromJson(
  Map<String, dynamic> json,
) => _$MatchSettingsImplImpl(
  goldenPoint: json['goldenPoint'] as bool? ?? true,
  tieBreakAtSixSix: json['tieBreakAtSixSix'] as bool? ?? true,
  tieBreakTarget: (json['tieBreakTarget'] as num?)?.toInt() ?? 7,
  setsToWin: (json['setsToWin'] as num?)?.toInt() ?? 2,
);

Map<String, dynamic> _$$MatchSettingsImplImplToJson(
  _$MatchSettingsImplImpl instance,
) => <String, dynamic>{
  'goldenPoint': instance.goldenPoint,
  'tieBreakAtSixSix': instance.tieBreakAtSixSix,
  'tieBreakTarget': instance.tieBreakTarget,
  'setsToWin': instance.setsToWin,
};

_$GamePointsImplImpl _$$GamePointsImplImplFromJson(Map<String, dynamic> json) =>
    _$GamePointsImplImpl(
      blue: (json['blue'] as num?)?.toInt() ?? 0,
      red: (json['red'] as num?)?.toInt() ?? 0,
      isTieBreak: json['isTieBreak'] as bool? ?? false,
    );

Map<String, dynamic> _$$GamePointsImplImplToJson(
  _$GamePointsImplImpl instance,
) => <String, dynamic>{
  'blue': instance.blue,
  'red': instance.red,
  'isTieBreak': instance.isTieBreak,
};

_$SetScoreImplImpl _$$SetScoreImplImplFromJson(
  Map<String, dynamic> json,
) => _$SetScoreImplImpl(
  blueGames: (json['blueGames'] as num?)?.toInt() ?? 0,
  redGames: (json['redGames'] as num?)?.toInt() ?? 0,
  currentGame:
      json['currentGame'] == null
          ? const GamePoints()
          : GamePoints.fromJson(json['currentGame'] as Map<String, dynamic>),
  tieBreakStarter: $enumDecodeNullable(_$TeamEnumMap, json['tieBreakStarter']),
);

Map<String, dynamic> _$$SetScoreImplImplToJson(_$SetScoreImplImpl instance) =>
    <String, dynamic>{
      'blueGames': instance.blueGames,
      'redGames': instance.redGames,
      'currentGame': instance.currentGame,
      'tieBreakStarter': _$TeamEnumMap[instance.tieBreakStarter],
    };

const _$TeamEnumMap = {Team.blue: 'blue', Team.red: 'red'};

_$MatchScoreImplImpl _$$MatchScoreImplImplFromJson(
  Map<String, dynamic> json,
) => _$MatchScoreImplImpl(
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

Map<String, dynamic> _$$MatchScoreImplImplToJson(
  _$MatchScoreImplImpl instance,
) => <String, dynamic>{
  'sets': instance.sets,
  'currentSetIndex': instance.currentSetIndex,
  'server': _$TeamEnumMap[instance.server]!,
  'receiver': _$TeamEnumMap[instance.receiver]!,
  'blueName': instance.blueName,
  'redName': instance.redName,
  'paused': instance.paused,
  'settings': instance.settings,
};
