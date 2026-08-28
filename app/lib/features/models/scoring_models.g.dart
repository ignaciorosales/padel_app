// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scoring_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerImpl _$$ServerImplFromJson(Map<String, dynamic> json) => _$ServerImpl(
  team: $enumDecodeNullable(_$TeamEnumMap, json['team']) ?? Team.blue,
  position:
      $enumDecodeNullable(_$PlayerPositionEnumMap, json['position']) ??
      PlayerPosition.drive,
);

Map<String, dynamic> _$$ServerImplToJson(_$ServerImpl instance) =>
    <String, dynamic>{
      'team': _$TeamEnumMap[instance.team]!,
      'position': _$PlayerPositionEnumMap[instance.position]!,
    };

const _$TeamEnumMap = {Team.blue: 'blue', Team.red: 'red'};

const _$PlayerPositionEnumMap = {
  PlayerPosition.drive: 'drive',
  PlayerPosition.backhand: 'backhand',
};

_$MatchSettingsImpl _$$MatchSettingsImplFromJson(Map<String, dynamic> json) =>
    _$MatchSettingsImpl(
      setsToWin: (json['setsToWin'] as num?)?.toInt() ?? 2,
      tieBreakAtGames: (json['tieBreakAtGames'] as num?)?.toInt() ?? 6,
      goldenPoint: json['goldenPoint'] as bool? ?? false,
      tieBreakTarget: (json['tieBreakTarget'] as num?)?.toInt() ?? 7,
      matchMode:
          $enumDecodeNullable(_$MatchModeEnumMap, json['matchMode']) ??
          MatchMode.amateur,
    );

Map<String, dynamic> _$$MatchSettingsImplToJson(_$MatchSettingsImpl instance) =>
    <String, dynamic>{
      'setsToWin': instance.setsToWin,
      'tieBreakAtGames': instance.tieBreakAtGames,
      'goldenPoint': instance.goldenPoint,
      'tieBreakTarget': instance.tieBreakTarget,
      'matchMode': _$MatchModeEnumMap[instance.matchMode]!,
    };

const _$MatchModeEnumMap = {
  MatchMode.amateur: 'amateur',
  MatchMode.championship: 'championship',
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
  tieBreakStartServer:
      json['tieBreakStartServer'] == null
          ? null
          : Server.fromJson(
            json['tieBreakStartServer'] as Map<String, dynamic>,
          ),
  tieBreakStarter: $enumDecodeNullable(_$TeamEnumMap, json['tieBreakStarter']),
  isSuperTieBreak: json['isSuperTieBreak'] as bool? ?? false,
);

Map<String, dynamic> _$$SetScoreImplToJson(_$SetScoreImpl instance) =>
    <String, dynamic>{
      'blueGames': instance.blueGames,
      'redGames': instance.redGames,
      'currentGame': instance.currentGame,
      'tieBreakStartServer': instance.tieBreakStartServer,
      'tieBreakStarter': _$TeamEnumMap[instance.tieBreakStarter],
      'isSuperTieBreak': instance.isSuperTieBreak,
    };

_$MatchScoreImpl _$$MatchScoreImplFromJson(
  Map<String, dynamic> json,
) => _$MatchScoreImpl(
  sets:
      (json['sets'] as List<dynamic>?)
          ?.map((e) => SetScore.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SetScore>[],
  currentSetIndex: (json['currentSetIndex'] as num?)?.toInt() ?? 0,
  currentServer:
      json['currentServer'] == null
          ? const Server()
          : Server.fromJson(json['currentServer'] as Map<String, dynamic>),
  server: $enumDecodeNullable(_$TeamEnumMap, json['server']) ?? Team.blue,
  receiver: $enumDecodeNullable(_$TeamEnumMap, json['receiver']) ?? Team.red,
  blueName: json['blueName'] as String? ?? 'Verde',
  redName: json['redName'] as String? ?? 'Negro',
  paused: json['paused'] as bool? ?? false,
  settings:
      json['settings'] == null
          ? const MatchSettings()
          : MatchSettings.fromJson(json['settings'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$MatchScoreImplToJson(_$MatchScoreImpl instance) =>
    <String, dynamic>{
      'sets': instance.sets,
      'currentSetIndex': instance.currentSetIndex,
      'currentServer': instance.currentServer,
      'server': _$TeamEnumMap[instance.server]!,
      'receiver': _$TeamEnumMap[instance.receiver]!,
      'blueName': instance.blueName,
      'redName': instance.redName,
      'paused': instance.paused,
      'settings': instance.settings,
    };
