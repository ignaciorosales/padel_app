// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scoring_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MatchSettings _$MatchSettingsFromJson(Map<String, dynamic> json) {
  return _MatchSettings.fromJson(json);
}

/// @nodoc
mixin _$MatchSettings {
  int get setsToWin => throw _privateConstructorUsedError;

  /// 6 (clásico) o 12 (super set)
  int get tieBreakAtGames => throw _privateConstructorUsedError;

  /// En deuce el siguiente punto decide
  bool get goldenPoint => throw _privateConstructorUsedError;

  /// Objetivo del TB (p.ej. 7 o 10, siempre con diferencia de 2)
  int get tieBreakTarget => throw _privateConstructorUsedError;

  /// Serializes this MatchSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchSettingsCopyWith<MatchSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchSettingsCopyWith<$Res> {
  factory $MatchSettingsCopyWith(
    MatchSettings value,
    $Res Function(MatchSettings) then,
  ) = _$MatchSettingsCopyWithImpl<$Res, MatchSettings>;
  @useResult
  $Res call({
    int setsToWin,
    int tieBreakAtGames,
    bool goldenPoint,
    int tieBreakTarget,
  });
}

/// @nodoc
class _$MatchSettingsCopyWithImpl<$Res, $Val extends MatchSettings>
    implements $MatchSettingsCopyWith<$Res> {
  _$MatchSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setsToWin = null,
    Object? tieBreakAtGames = null,
    Object? goldenPoint = null,
    Object? tieBreakTarget = null,
  }) {
    return _then(
      _value.copyWith(
            setsToWin:
                null == setsToWin
                    ? _value.setsToWin
                    : setsToWin // ignore: cast_nullable_to_non_nullable
                        as int,
            tieBreakAtGames:
                null == tieBreakAtGames
                    ? _value.tieBreakAtGames
                    : tieBreakAtGames // ignore: cast_nullable_to_non_nullable
                        as int,
            goldenPoint:
                null == goldenPoint
                    ? _value.goldenPoint
                    : goldenPoint // ignore: cast_nullable_to_non_nullable
                        as bool,
            tieBreakTarget:
                null == tieBreakTarget
                    ? _value.tieBreakTarget
                    : tieBreakTarget // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MatchSettingsImplCopyWith<$Res>
    implements $MatchSettingsCopyWith<$Res> {
  factory _$$MatchSettingsImplCopyWith(
    _$MatchSettingsImpl value,
    $Res Function(_$MatchSettingsImpl) then,
  ) = __$$MatchSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int setsToWin,
    int tieBreakAtGames,
    bool goldenPoint,
    int tieBreakTarget,
  });
}

/// @nodoc
class __$$MatchSettingsImplCopyWithImpl<$Res>
    extends _$MatchSettingsCopyWithImpl<$Res, _$MatchSettingsImpl>
    implements _$$MatchSettingsImplCopyWith<$Res> {
  __$$MatchSettingsImplCopyWithImpl(
    _$MatchSettingsImpl _value,
    $Res Function(_$MatchSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setsToWin = null,
    Object? tieBreakAtGames = null,
    Object? goldenPoint = null,
    Object? tieBreakTarget = null,
  }) {
    return _then(
      _$MatchSettingsImpl(
        setsToWin:
            null == setsToWin
                ? _value.setsToWin
                : setsToWin // ignore: cast_nullable_to_non_nullable
                    as int,
        tieBreakAtGames:
            null == tieBreakAtGames
                ? _value.tieBreakAtGames
                : tieBreakAtGames // ignore: cast_nullable_to_non_nullable
                    as int,
        goldenPoint:
            null == goldenPoint
                ? _value.goldenPoint
                : goldenPoint // ignore: cast_nullable_to_non_nullable
                    as bool,
        tieBreakTarget:
            null == tieBreakTarget
                ? _value.tieBreakTarget
                : tieBreakTarget // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchSettingsImpl implements _MatchSettings {
  const _$MatchSettingsImpl({
    this.setsToWin = 2,
    this.tieBreakAtGames = 6,
    this.goldenPoint = false,
    this.tieBreakTarget = 7,
  });

  factory _$MatchSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchSettingsImplFromJson(json);

  @override
  @JsonKey()
  final int setsToWin;

  /// 6 (clásico) o 12 (super set)
  @override
  @JsonKey()
  final int tieBreakAtGames;

  /// En deuce el siguiente punto decide
  @override
  @JsonKey()
  final bool goldenPoint;

  /// Objetivo del TB (p.ej. 7 o 10, siempre con diferencia de 2)
  @override
  @JsonKey()
  final int tieBreakTarget;

  @override
  String toString() {
    return 'MatchSettings(setsToWin: $setsToWin, tieBreakAtGames: $tieBreakAtGames, goldenPoint: $goldenPoint, tieBreakTarget: $tieBreakTarget)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchSettingsImpl &&
            (identical(other.setsToWin, setsToWin) ||
                other.setsToWin == setsToWin) &&
            (identical(other.tieBreakAtGames, tieBreakAtGames) ||
                other.tieBreakAtGames == tieBreakAtGames) &&
            (identical(other.goldenPoint, goldenPoint) ||
                other.goldenPoint == goldenPoint) &&
            (identical(other.tieBreakTarget, tieBreakTarget) ||
                other.tieBreakTarget == tieBreakTarget));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    setsToWin,
    tieBreakAtGames,
    goldenPoint,
    tieBreakTarget,
  );

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchSettingsImplCopyWith<_$MatchSettingsImpl> get copyWith =>
      __$$MatchSettingsImplCopyWithImpl<_$MatchSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchSettingsImplToJson(this);
  }
}

abstract class _MatchSettings implements MatchSettings {
  const factory _MatchSettings({
    final int setsToWin,
    final int tieBreakAtGames,
    final bool goldenPoint,
    final int tieBreakTarget,
  }) = _$MatchSettingsImpl;

  factory _MatchSettings.fromJson(Map<String, dynamic> json) =
      _$MatchSettingsImpl.fromJson;

  @override
  int get setsToWin;

  /// 6 (clásico) o 12 (super set)
  @override
  int get tieBreakAtGames;

  /// En deuce el siguiente punto decide
  @override
  bool get goldenPoint;

  /// Objetivo del TB (p.ej. 7 o 10, siempre con diferencia de 2)
  @override
  int get tieBreakTarget;

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchSettingsImplCopyWith<_$MatchSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GamePoints _$GamePointsFromJson(Map<String, dynamic> json) {
  return _GamePoints.fromJson(json);
}

/// @nodoc
mixin _$GamePoints {
  int get blue => throw _privateConstructorUsedError;
  int get red => throw _privateConstructorUsedError;
  bool get isTieBreak => throw _privateConstructorUsedError;

  /// Serializes this GamePoints to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GamePoints
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GamePointsCopyWith<GamePoints> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GamePointsCopyWith<$Res> {
  factory $GamePointsCopyWith(
    GamePoints value,
    $Res Function(GamePoints) then,
  ) = _$GamePointsCopyWithImpl<$Res, GamePoints>;
  @useResult
  $Res call({int blue, int red, bool isTieBreak});
}

/// @nodoc
class _$GamePointsCopyWithImpl<$Res, $Val extends GamePoints>
    implements $GamePointsCopyWith<$Res> {
  _$GamePointsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GamePoints
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blue = null,
    Object? red = null,
    Object? isTieBreak = null,
  }) {
    return _then(
      _value.copyWith(
            blue:
                null == blue
                    ? _value.blue
                    : blue // ignore: cast_nullable_to_non_nullable
                        as int,
            red:
                null == red
                    ? _value.red
                    : red // ignore: cast_nullable_to_non_nullable
                        as int,
            isTieBreak:
                null == isTieBreak
                    ? _value.isTieBreak
                    : isTieBreak // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GamePointsImplCopyWith<$Res>
    implements $GamePointsCopyWith<$Res> {
  factory _$$GamePointsImplCopyWith(
    _$GamePointsImpl value,
    $Res Function(_$GamePointsImpl) then,
  ) = __$$GamePointsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int blue, int red, bool isTieBreak});
}

/// @nodoc
class __$$GamePointsImplCopyWithImpl<$Res>
    extends _$GamePointsCopyWithImpl<$Res, _$GamePointsImpl>
    implements _$$GamePointsImplCopyWith<$Res> {
  __$$GamePointsImplCopyWithImpl(
    _$GamePointsImpl _value,
    $Res Function(_$GamePointsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GamePoints
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blue = null,
    Object? red = null,
    Object? isTieBreak = null,
  }) {
    return _then(
      _$GamePointsImpl(
        blue:
            null == blue
                ? _value.blue
                : blue // ignore: cast_nullable_to_non_nullable
                    as int,
        red:
            null == red
                ? _value.red
                : red // ignore: cast_nullable_to_non_nullable
                    as int,
        isTieBreak:
            null == isTieBreak
                ? _value.isTieBreak
                : isTieBreak // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GamePointsImpl implements _GamePoints {
  const _$GamePointsImpl({
    this.blue = 0,
    this.red = 0,
    this.isTieBreak = false,
  });

  factory _$GamePointsImpl.fromJson(Map<String, dynamic> json) =>
      _$$GamePointsImplFromJson(json);

  @override
  @JsonKey()
  final int blue;
  @override
  @JsonKey()
  final int red;
  @override
  @JsonKey()
  final bool isTieBreak;

  @override
  String toString() {
    return 'GamePoints(blue: $blue, red: $red, isTieBreak: $isTieBreak)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GamePointsImpl &&
            (identical(other.blue, blue) || other.blue == blue) &&
            (identical(other.red, red) || other.red == red) &&
            (identical(other.isTieBreak, isTieBreak) ||
                other.isTieBreak == isTieBreak));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, blue, red, isTieBreak);

  /// Create a copy of GamePoints
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GamePointsImplCopyWith<_$GamePointsImpl> get copyWith =>
      __$$GamePointsImplCopyWithImpl<_$GamePointsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GamePointsImplToJson(this);
  }
}

abstract class _GamePoints implements GamePoints {
  const factory _GamePoints({
    final int blue,
    final int red,
    final bool isTieBreak,
  }) = _$GamePointsImpl;

  factory _GamePoints.fromJson(Map<String, dynamic> json) =
      _$GamePointsImpl.fromJson;

  @override
  int get blue;
  @override
  int get red;
  @override
  bool get isTieBreak;

  /// Create a copy of GamePoints
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GamePointsImplCopyWith<_$GamePointsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SetScore _$SetScoreFromJson(Map<String, dynamic> json) {
  return _SetScore.fromJson(json);
}

/// @nodoc
mixin _$SetScore {
  int get blueGames => throw _privateConstructorUsedError;
  int get redGames => throw _privateConstructorUsedError;
  GamePoints get currentGame => throw _privateConstructorUsedError;

  /// Servidor que comenzó el tie-break (rotación 1–2–2–2)
  Team? get tieBreakStarter => throw _privateConstructorUsedError;

  /// Serializes this SetScore to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SetScoreCopyWith<SetScore> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SetScoreCopyWith<$Res> {
  factory $SetScoreCopyWith(SetScore value, $Res Function(SetScore) then) =
      _$SetScoreCopyWithImpl<$Res, SetScore>;
  @useResult
  $Res call({
    int blueGames,
    int redGames,
    GamePoints currentGame,
    Team? tieBreakStarter,
  });

  $GamePointsCopyWith<$Res> get currentGame;
}

/// @nodoc
class _$SetScoreCopyWithImpl<$Res, $Val extends SetScore>
    implements $SetScoreCopyWith<$Res> {
  _$SetScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blueGames = null,
    Object? redGames = null,
    Object? currentGame = null,
    Object? tieBreakStarter = freezed,
  }) {
    return _then(
      _value.copyWith(
            blueGames:
                null == blueGames
                    ? _value.blueGames
                    : blueGames // ignore: cast_nullable_to_non_nullable
                        as int,
            redGames:
                null == redGames
                    ? _value.redGames
                    : redGames // ignore: cast_nullable_to_non_nullable
                        as int,
            currentGame:
                null == currentGame
                    ? _value.currentGame
                    : currentGame // ignore: cast_nullable_to_non_nullable
                        as GamePoints,
            tieBreakStarter:
                freezed == tieBreakStarter
                    ? _value.tieBreakStarter
                    : tieBreakStarter // ignore: cast_nullable_to_non_nullable
                        as Team?,
          )
          as $Val,
    );
  }

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GamePointsCopyWith<$Res> get currentGame {
    return $GamePointsCopyWith<$Res>(_value.currentGame, (value) {
      return _then(_value.copyWith(currentGame: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SetScoreImplCopyWith<$Res>
    implements $SetScoreCopyWith<$Res> {
  factory _$$SetScoreImplCopyWith(
    _$SetScoreImpl value,
    $Res Function(_$SetScoreImpl) then,
  ) = __$$SetScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int blueGames,
    int redGames,
    GamePoints currentGame,
    Team? tieBreakStarter,
  });

  @override
  $GamePointsCopyWith<$Res> get currentGame;
}

/// @nodoc
class __$$SetScoreImplCopyWithImpl<$Res>
    extends _$SetScoreCopyWithImpl<$Res, _$SetScoreImpl>
    implements _$$SetScoreImplCopyWith<$Res> {
  __$$SetScoreImplCopyWithImpl(
    _$SetScoreImpl _value,
    $Res Function(_$SetScoreImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blueGames = null,
    Object? redGames = null,
    Object? currentGame = null,
    Object? tieBreakStarter = freezed,
  }) {
    return _then(
      _$SetScoreImpl(
        blueGames:
            null == blueGames
                ? _value.blueGames
                : blueGames // ignore: cast_nullable_to_non_nullable
                    as int,
        redGames:
            null == redGames
                ? _value.redGames
                : redGames // ignore: cast_nullable_to_non_nullable
                    as int,
        currentGame:
            null == currentGame
                ? _value.currentGame
                : currentGame // ignore: cast_nullable_to_non_nullable
                    as GamePoints,
        tieBreakStarter:
            freezed == tieBreakStarter
                ? _value.tieBreakStarter
                : tieBreakStarter // ignore: cast_nullable_to_non_nullable
                    as Team?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SetScoreImpl implements _SetScore {
  const _$SetScoreImpl({
    this.blueGames = 0,
    this.redGames = 0,
    this.currentGame = const GamePoints(),
    this.tieBreakStarter,
  });

  factory _$SetScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$SetScoreImplFromJson(json);

  @override
  @JsonKey()
  final int blueGames;
  @override
  @JsonKey()
  final int redGames;
  @override
  @JsonKey()
  final GamePoints currentGame;

  /// Servidor que comenzó el tie-break (rotación 1–2–2–2)
  @override
  final Team? tieBreakStarter;

  @override
  String toString() {
    return 'SetScore(blueGames: $blueGames, redGames: $redGames, currentGame: $currentGame, tieBreakStarter: $tieBreakStarter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetScoreImpl &&
            (identical(other.blueGames, blueGames) ||
                other.blueGames == blueGames) &&
            (identical(other.redGames, redGames) ||
                other.redGames == redGames) &&
            (identical(other.currentGame, currentGame) ||
                other.currentGame == currentGame) &&
            (identical(other.tieBreakStarter, tieBreakStarter) ||
                other.tieBreakStarter == tieBreakStarter));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    blueGames,
    redGames,
    currentGame,
    tieBreakStarter,
  );

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SetScoreImplCopyWith<_$SetScoreImpl> get copyWith =>
      __$$SetScoreImplCopyWithImpl<_$SetScoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SetScoreImplToJson(this);
  }
}

abstract class _SetScore implements SetScore {
  const factory _SetScore({
    final int blueGames,
    final int redGames,
    final GamePoints currentGame,
    final Team? tieBreakStarter,
  }) = _$SetScoreImpl;

  factory _SetScore.fromJson(Map<String, dynamic> json) =
      _$SetScoreImpl.fromJson;

  @override
  int get blueGames;
  @override
  int get redGames;
  @override
  GamePoints get currentGame;

  /// Servidor que comenzó el tie-break (rotación 1–2–2–2)
  @override
  Team? get tieBreakStarter;

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetScoreImplCopyWith<_$SetScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatchScore _$MatchScoreFromJson(Map<String, dynamic> json) {
  return _MatchScore.fromJson(json);
}

/// @nodoc
mixin _$MatchScore {
  List<SetScore> get sets => throw _privateConstructorUsedError;
  int get currentSetIndex => throw _privateConstructorUsedError;
  Team get server => throw _privateConstructorUsedError;
  Team get receiver => throw _privateConstructorUsedError;
  String get blueName => throw _privateConstructorUsedError;
  String get redName => throw _privateConstructorUsedError;
  bool get paused => throw _privateConstructorUsedError;
  MatchSettings get settings => throw _privateConstructorUsedError;

  /// Serializes this MatchScore to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchScoreCopyWith<MatchScore> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchScoreCopyWith<$Res> {
  factory $MatchScoreCopyWith(
    MatchScore value,
    $Res Function(MatchScore) then,
  ) = _$MatchScoreCopyWithImpl<$Res, MatchScore>;
  @useResult
  $Res call({
    List<SetScore> sets,
    int currentSetIndex,
    Team server,
    Team receiver,
    String blueName,
    String redName,
    bool paused,
    MatchSettings settings,
  });

  $MatchSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$MatchScoreCopyWithImpl<$Res, $Val extends MatchScore>
    implements $MatchScoreCopyWith<$Res> {
  _$MatchScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sets = null,
    Object? currentSetIndex = null,
    Object? server = null,
    Object? receiver = null,
    Object? blueName = null,
    Object? redName = null,
    Object? paused = null,
    Object? settings = null,
  }) {
    return _then(
      _value.copyWith(
            sets:
                null == sets
                    ? _value.sets
                    : sets // ignore: cast_nullable_to_non_nullable
                        as List<SetScore>,
            currentSetIndex:
                null == currentSetIndex
                    ? _value.currentSetIndex
                    : currentSetIndex // ignore: cast_nullable_to_non_nullable
                        as int,
            server:
                null == server
                    ? _value.server
                    : server // ignore: cast_nullable_to_non_nullable
                        as Team,
            receiver:
                null == receiver
                    ? _value.receiver
                    : receiver // ignore: cast_nullable_to_non_nullable
                        as Team,
            blueName:
                null == blueName
                    ? _value.blueName
                    : blueName // ignore: cast_nullable_to_non_nullable
                        as String,
            redName:
                null == redName
                    ? _value.redName
                    : redName // ignore: cast_nullable_to_non_nullable
                        as String,
            paused:
                null == paused
                    ? _value.paused
                    : paused // ignore: cast_nullable_to_non_nullable
                        as bool,
            settings:
                null == settings
                    ? _value.settings
                    : settings // ignore: cast_nullable_to_non_nullable
                        as MatchSettings,
          )
          as $Val,
    );
  }

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MatchSettingsCopyWith<$Res> get settings {
    return $MatchSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MatchScoreImplCopyWith<$Res>
    implements $MatchScoreCopyWith<$Res> {
  factory _$$MatchScoreImplCopyWith(
    _$MatchScoreImpl value,
    $Res Function(_$MatchScoreImpl) then,
  ) = __$$MatchScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<SetScore> sets,
    int currentSetIndex,
    Team server,
    Team receiver,
    String blueName,
    String redName,
    bool paused,
    MatchSettings settings,
  });

  @override
  $MatchSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$MatchScoreImplCopyWithImpl<$Res>
    extends _$MatchScoreCopyWithImpl<$Res, _$MatchScoreImpl>
    implements _$$MatchScoreImplCopyWith<$Res> {
  __$$MatchScoreImplCopyWithImpl(
    _$MatchScoreImpl _value,
    $Res Function(_$MatchScoreImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sets = null,
    Object? currentSetIndex = null,
    Object? server = null,
    Object? receiver = null,
    Object? blueName = null,
    Object? redName = null,
    Object? paused = null,
    Object? settings = null,
  }) {
    return _then(
      _$MatchScoreImpl(
        sets:
            null == sets
                ? _value._sets
                : sets // ignore: cast_nullable_to_non_nullable
                    as List<SetScore>,
        currentSetIndex:
            null == currentSetIndex
                ? _value.currentSetIndex
                : currentSetIndex // ignore: cast_nullable_to_non_nullable
                    as int,
        server:
            null == server
                ? _value.server
                : server // ignore: cast_nullable_to_non_nullable
                    as Team,
        receiver:
            null == receiver
                ? _value.receiver
                : receiver // ignore: cast_nullable_to_non_nullable
                    as Team,
        blueName:
            null == blueName
                ? _value.blueName
                : blueName // ignore: cast_nullable_to_non_nullable
                    as String,
        redName:
            null == redName
                ? _value.redName
                : redName // ignore: cast_nullable_to_non_nullable
                    as String,
        paused:
            null == paused
                ? _value.paused
                : paused // ignore: cast_nullable_to_non_nullable
                    as bool,
        settings:
            null == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                    as MatchSettings,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$MatchScoreImpl extends _MatchScore {
  const _$MatchScoreImpl({
    final List<SetScore> sets = const <SetScore>[],
    this.currentSetIndex = 0,
    this.server = Team.blue,
    this.receiver = Team.red,
    this.blueName = 'Azul',
    this.redName = 'Rojo',
    this.paused = false,
    this.settings = const MatchSettings(),
  }) : _sets = sets,
       super._();

  factory _$MatchScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchScoreImplFromJson(json);

  final List<SetScore> _sets;
  @override
  @JsonKey()
  List<SetScore> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  @override
  @JsonKey()
  final int currentSetIndex;
  @override
  @JsonKey()
  final Team server;
  @override
  @JsonKey()
  final Team receiver;
  @override
  @JsonKey()
  final String blueName;
  @override
  @JsonKey()
  final String redName;
  @override
  @JsonKey()
  final bool paused;
  @override
  @JsonKey()
  final MatchSettings settings;

  @override
  String toString() {
    return 'MatchScore(sets: $sets, currentSetIndex: $currentSetIndex, server: $server, receiver: $receiver, blueName: $blueName, redName: $redName, paused: $paused, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchScoreImpl &&
            const DeepCollectionEquality().equals(other._sets, _sets) &&
            (identical(other.currentSetIndex, currentSetIndex) ||
                other.currentSetIndex == currentSetIndex) &&
            (identical(other.server, server) || other.server == server) &&
            (identical(other.receiver, receiver) ||
                other.receiver == receiver) &&
            (identical(other.blueName, blueName) ||
                other.blueName == blueName) &&
            (identical(other.redName, redName) || other.redName == redName) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            (identical(other.settings, settings) ||
                other.settings == settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_sets),
    currentSetIndex,
    server,
    receiver,
    blueName,
    redName,
    paused,
    settings,
  );

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchScoreImplCopyWith<_$MatchScoreImpl> get copyWith =>
      __$$MatchScoreImplCopyWithImpl<_$MatchScoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchScoreImplToJson(this);
  }
}

abstract class _MatchScore extends MatchScore {
  const factory _MatchScore({
    final List<SetScore> sets,
    final int currentSetIndex,
    final Team server,
    final Team receiver,
    final String blueName,
    final String redName,
    final bool paused,
    final MatchSettings settings,
  }) = _$MatchScoreImpl;
  const _MatchScore._() : super._();

  factory _MatchScore.fromJson(Map<String, dynamic> json) =
      _$MatchScoreImpl.fromJson;

  @override
  List<SetScore> get sets;
  @override
  int get currentSetIndex;
  @override
  Team get server;
  @override
  Team get receiver;
  @override
  String get blueName;
  @override
  String get redName;
  @override
  bool get paused;
  @override
  MatchSettings get settings;

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchScoreImplCopyWith<_$MatchScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
