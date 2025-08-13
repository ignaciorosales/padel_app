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
  return MatchSettingsImpl.fromJson(json);
}

/// @nodoc
mixin _$MatchSettings {
  bool get goldenPoint =>
      throw _privateConstructorUsedError; // punto de oro a 40–40
  bool get tieBreakAtSixSix =>
      throw _privateConstructorUsedError; // tiebreak a 6–6
  int get tieBreakTarget =>
      throw _privateConstructorUsedError; // 7 con diferencia de 2
  int get setsToWin => throw _privateConstructorUsedError;

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
    bool goldenPoint,
    bool tieBreakAtSixSix,
    int tieBreakTarget,
    int setsToWin,
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
    Object? goldenPoint = null,
    Object? tieBreakAtSixSix = null,
    Object? tieBreakTarget = null,
    Object? setsToWin = null,
  }) {
    return _then(
      _value.copyWith(
            goldenPoint:
                null == goldenPoint
                    ? _value.goldenPoint
                    : goldenPoint // ignore: cast_nullable_to_non_nullable
                        as bool,
            tieBreakAtSixSix:
                null == tieBreakAtSixSix
                    ? _value.tieBreakAtSixSix
                    : tieBreakAtSixSix // ignore: cast_nullable_to_non_nullable
                        as bool,
            tieBreakTarget:
                null == tieBreakTarget
                    ? _value.tieBreakTarget
                    : tieBreakTarget // ignore: cast_nullable_to_non_nullable
                        as int,
            setsToWin:
                null == setsToWin
                    ? _value.setsToWin
                    : setsToWin // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MatchSettingsImplImplCopyWith<$Res>
    implements $MatchSettingsCopyWith<$Res> {
  factory _$$MatchSettingsImplImplCopyWith(
    _$MatchSettingsImplImpl value,
    $Res Function(_$MatchSettingsImplImpl) then,
  ) = __$$MatchSettingsImplImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool goldenPoint,
    bool tieBreakAtSixSix,
    int tieBreakTarget,
    int setsToWin,
  });
}

/// @nodoc
class __$$MatchSettingsImplImplCopyWithImpl<$Res>
    extends _$MatchSettingsCopyWithImpl<$Res, _$MatchSettingsImplImpl>
    implements _$$MatchSettingsImplImplCopyWith<$Res> {
  __$$MatchSettingsImplImplCopyWithImpl(
    _$MatchSettingsImplImpl _value,
    $Res Function(_$MatchSettingsImplImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goldenPoint = null,
    Object? tieBreakAtSixSix = null,
    Object? tieBreakTarget = null,
    Object? setsToWin = null,
  }) {
    return _then(
      _$MatchSettingsImplImpl(
        goldenPoint:
            null == goldenPoint
                ? _value.goldenPoint
                : goldenPoint // ignore: cast_nullable_to_non_nullable
                    as bool,
        tieBreakAtSixSix:
            null == tieBreakAtSixSix
                ? _value.tieBreakAtSixSix
                : tieBreakAtSixSix // ignore: cast_nullable_to_non_nullable
                    as bool,
        tieBreakTarget:
            null == tieBreakTarget
                ? _value.tieBreakTarget
                : tieBreakTarget // ignore: cast_nullable_to_non_nullable
                    as int,
        setsToWin:
            null == setsToWin
                ? _value.setsToWin
                : setsToWin // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchSettingsImplImpl implements MatchSettingsImpl {
  const _$MatchSettingsImplImpl({
    this.goldenPoint = true,
    this.tieBreakAtSixSix = true,
    this.tieBreakTarget = 7,
    this.setsToWin = 2,
  });

  factory _$MatchSettingsImplImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchSettingsImplImplFromJson(json);

  @override
  @JsonKey()
  final bool goldenPoint;
  // punto de oro a 40–40
  @override
  @JsonKey()
  final bool tieBreakAtSixSix;
  // tiebreak a 6–6
  @override
  @JsonKey()
  final int tieBreakTarget;
  // 7 con diferencia de 2
  @override
  @JsonKey()
  final int setsToWin;

  @override
  String toString() {
    return 'MatchSettings(goldenPoint: $goldenPoint, tieBreakAtSixSix: $tieBreakAtSixSix, tieBreakTarget: $tieBreakTarget, setsToWin: $setsToWin)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchSettingsImplImpl &&
            (identical(other.goldenPoint, goldenPoint) ||
                other.goldenPoint == goldenPoint) &&
            (identical(other.tieBreakAtSixSix, tieBreakAtSixSix) ||
                other.tieBreakAtSixSix == tieBreakAtSixSix) &&
            (identical(other.tieBreakTarget, tieBreakTarget) ||
                other.tieBreakTarget == tieBreakTarget) &&
            (identical(other.setsToWin, setsToWin) ||
                other.setsToWin == setsToWin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    goldenPoint,
    tieBreakAtSixSix,
    tieBreakTarget,
    setsToWin,
  );

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchSettingsImplImplCopyWith<_$MatchSettingsImplImpl> get copyWith =>
      __$$MatchSettingsImplImplCopyWithImpl<_$MatchSettingsImplImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchSettingsImplImplToJson(this);
  }
}

abstract class MatchSettingsImpl implements MatchSettings {
  const factory MatchSettingsImpl({
    final bool goldenPoint,
    final bool tieBreakAtSixSix,
    final int tieBreakTarget,
    final int setsToWin,
  }) = _$MatchSettingsImplImpl;

  factory MatchSettingsImpl.fromJson(Map<String, dynamic> json) =
      _$MatchSettingsImplImpl.fromJson;

  @override
  bool get goldenPoint; // punto de oro a 40–40
  @override
  bool get tieBreakAtSixSix; // tiebreak a 6–6
  @override
  int get tieBreakTarget; // 7 con diferencia de 2
  @override
  int get setsToWin;

  /// Create a copy of MatchSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchSettingsImplImplCopyWith<_$MatchSettingsImplImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GamePoints _$GamePointsFromJson(Map<String, dynamic> json) {
  return GamePointsImpl.fromJson(json);
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
abstract class _$$GamePointsImplImplCopyWith<$Res>
    implements $GamePointsCopyWith<$Res> {
  factory _$$GamePointsImplImplCopyWith(
    _$GamePointsImplImpl value,
    $Res Function(_$GamePointsImplImpl) then,
  ) = __$$GamePointsImplImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int blue, int red, bool isTieBreak});
}

/// @nodoc
class __$$GamePointsImplImplCopyWithImpl<$Res>
    extends _$GamePointsCopyWithImpl<$Res, _$GamePointsImplImpl>
    implements _$$GamePointsImplImplCopyWith<$Res> {
  __$$GamePointsImplImplCopyWithImpl(
    _$GamePointsImplImpl _value,
    $Res Function(_$GamePointsImplImpl) _then,
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
      _$GamePointsImplImpl(
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
class _$GamePointsImplImpl implements GamePointsImpl {
  const _$GamePointsImplImpl({
    this.blue = 0,
    this.red = 0,
    this.isTieBreak = false,
  });

  factory _$GamePointsImplImpl.fromJson(Map<String, dynamic> json) =>
      _$$GamePointsImplImplFromJson(json);

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
            other is _$GamePointsImplImpl &&
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
  _$$GamePointsImplImplCopyWith<_$GamePointsImplImpl> get copyWith =>
      __$$GamePointsImplImplCopyWithImpl<_$GamePointsImplImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GamePointsImplImplToJson(this);
  }
}

abstract class GamePointsImpl implements GamePoints {
  const factory GamePointsImpl({
    final int blue,
    final int red,
    final bool isTieBreak,
  }) = _$GamePointsImplImpl;

  factory GamePointsImpl.fromJson(Map<String, dynamic> json) =
      _$GamePointsImplImpl.fromJson;

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
  _$$GamePointsImplImplCopyWith<_$GamePointsImplImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SetScore _$SetScoreFromJson(Map<String, dynamic> json) {
  return SetScoreImpl.fromJson(json);
}

/// @nodoc
mixin _$SetScore {
  int get blueGames => throw _privateConstructorUsedError;
  int get redGames => throw _privateConstructorUsedError;
  GamePoints get currentGame => throw _privateConstructorUsedError;
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
abstract class _$$SetScoreImplImplCopyWith<$Res>
    implements $SetScoreCopyWith<$Res> {
  factory _$$SetScoreImplImplCopyWith(
    _$SetScoreImplImpl value,
    $Res Function(_$SetScoreImplImpl) then,
  ) = __$$SetScoreImplImplCopyWithImpl<$Res>;
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
class __$$SetScoreImplImplCopyWithImpl<$Res>
    extends _$SetScoreCopyWithImpl<$Res, _$SetScoreImplImpl>
    implements _$$SetScoreImplImplCopyWith<$Res> {
  __$$SetScoreImplImplCopyWithImpl(
    _$SetScoreImplImpl _value,
    $Res Function(_$SetScoreImplImpl) _then,
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
      _$SetScoreImplImpl(
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
class _$SetScoreImplImpl implements SetScoreImpl {
  const _$SetScoreImplImpl({
    this.blueGames = 0,
    this.redGames = 0,
    this.currentGame = const GamePoints(),
    this.tieBreakStarter,
  });

  factory _$SetScoreImplImpl.fromJson(Map<String, dynamic> json) =>
      _$$SetScoreImplImplFromJson(json);

  @override
  @JsonKey()
  final int blueGames;
  @override
  @JsonKey()
  final int redGames;
  @override
  @JsonKey()
  final GamePoints currentGame;
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
            other is _$SetScoreImplImpl &&
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
  _$$SetScoreImplImplCopyWith<_$SetScoreImplImpl> get copyWith =>
      __$$SetScoreImplImplCopyWithImpl<_$SetScoreImplImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SetScoreImplImplToJson(this);
  }
}

abstract class SetScoreImpl implements SetScore {
  const factory SetScoreImpl({
    final int blueGames,
    final int redGames,
    final GamePoints currentGame,
    final Team? tieBreakStarter,
  }) = _$SetScoreImplImpl;

  factory SetScoreImpl.fromJson(Map<String, dynamic> json) =
      _$SetScoreImplImpl.fromJson;

  @override
  int get blueGames;
  @override
  int get redGames;
  @override
  GamePoints get currentGame;
  @override
  Team? get tieBreakStarter;

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetScoreImplImplCopyWith<_$SetScoreImplImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatchScore _$MatchScoreFromJson(Map<String, dynamic> json) {
  return MatchScoreImpl.fromJson(json);
}

/// @nodoc
mixin _$MatchScore {
  List<SetScore> get sets => throw _privateConstructorUsedError;
  int get currentSetIndex => throw _privateConstructorUsedError;
  Team get server => throw _privateConstructorUsedError;
  Team get receiver => throw _privateConstructorUsedError;
  String get blueName =>
      throw _privateConstructorUsedError; // se sobreescribe desde config en runtime
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
abstract class _$$MatchScoreImplImplCopyWith<$Res>
    implements $MatchScoreCopyWith<$Res> {
  factory _$$MatchScoreImplImplCopyWith(
    _$MatchScoreImplImpl value,
    $Res Function(_$MatchScoreImplImpl) then,
  ) = __$$MatchScoreImplImplCopyWithImpl<$Res>;
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
class __$$MatchScoreImplImplCopyWithImpl<$Res>
    extends _$MatchScoreCopyWithImpl<$Res, _$MatchScoreImplImpl>
    implements _$$MatchScoreImplImplCopyWith<$Res> {
  __$$MatchScoreImplImplCopyWithImpl(
    _$MatchScoreImplImpl _value,
    $Res Function(_$MatchScoreImplImpl) _then,
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
      _$MatchScoreImplImpl(
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
@JsonSerializable()
class _$MatchScoreImplImpl extends MatchScoreImpl {
  const _$MatchScoreImplImpl({
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

  factory _$MatchScoreImplImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchScoreImplImplFromJson(json);

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
  // se sobreescribe desde config en runtime
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
            other is _$MatchScoreImplImpl &&
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
  _$$MatchScoreImplImplCopyWith<_$MatchScoreImplImpl> get copyWith =>
      __$$MatchScoreImplImplCopyWithImpl<_$MatchScoreImplImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchScoreImplImplToJson(this);
  }
}

abstract class MatchScoreImpl extends MatchScore {
  const factory MatchScoreImpl({
    final List<SetScore> sets,
    final int currentSetIndex,
    final Team server,
    final Team receiver,
    final String blueName,
    final String redName,
    final bool paused,
    final MatchSettings settings,
  }) = _$MatchScoreImplImpl;
  const MatchScoreImpl._() : super._();

  factory MatchScoreImpl.fromJson(Map<String, dynamic> json) =
      _$MatchScoreImplImpl.fromJson;

  @override
  List<SetScore> get sets;
  @override
  int get currentSetIndex;
  @override
  Team get server;
  @override
  Team get receiver;
  @override
  String get blueName; // se sobreescribe desde config en runtime
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
  _$$MatchScoreImplImplCopyWith<_$MatchScoreImplImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
