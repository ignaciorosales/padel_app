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

Server _$ServerFromJson(Map<String, dynamic> json) {
  return _Server.fromJson(json);
}

/// @nodoc
mixin _$Server {
  /// Equipo que tiene el servicio
  Team get team => throw _privateConstructorUsedError;

  /// Posición del jugador que saca (drive o revés)
  PlayerPosition get position => throw _privateConstructorUsedError;

  /// Serializes this Server to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServerCopyWith<Server> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServerCopyWith<$Res> {
  factory $ServerCopyWith(Server value, $Res Function(Server) then) =
      _$ServerCopyWithImpl<$Res, Server>;
  @useResult
  $Res call({Team team, PlayerPosition position});
}

/// @nodoc
class _$ServerCopyWithImpl<$Res, $Val extends Server>
    implements $ServerCopyWith<$Res> {
  _$ServerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null, Object? position = null}) {
    return _then(
      _value.copyWith(
            team:
                null == team
                    ? _value.team
                    : team // ignore: cast_nullable_to_non_nullable
                        as Team,
            position:
                null == position
                    ? _value.position
                    : position // ignore: cast_nullable_to_non_nullable
                        as PlayerPosition,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ServerImplCopyWith<$Res> implements $ServerCopyWith<$Res> {
  factory _$$ServerImplCopyWith(
    _$ServerImpl value,
    $Res Function(_$ServerImpl) then,
  ) = __$$ServerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Team team, PlayerPosition position});
}

/// @nodoc
class __$$ServerImplCopyWithImpl<$Res>
    extends _$ServerCopyWithImpl<$Res, _$ServerImpl>
    implements _$$ServerImplCopyWith<$Res> {
  __$$ServerImplCopyWithImpl(
    _$ServerImpl _value,
    $Res Function(_$ServerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null, Object? position = null}) {
    return _then(
      _$ServerImpl(
        team:
            null == team
                ? _value.team
                : team // ignore: cast_nullable_to_non_nullable
                    as Team,
        position:
            null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                    as PlayerPosition,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerImpl extends _Server {
  const _$ServerImpl({
    this.team = Team.blue,
    this.position = PlayerPosition.drive,
  }) : super._();

  factory _$ServerImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerImplFromJson(json);

  /// Equipo que tiene el servicio
  @override
  @JsonKey()
  final Team team;

  /// Posición del jugador que saca (drive o revés)
  @override
  @JsonKey()
  final PlayerPosition position;

  @override
  String toString() {
    return 'Server(team: $team, position: $position)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerImpl &&
            (identical(other.team, team) || other.team == team) &&
            (identical(other.position, position) ||
                other.position == position));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, team, position);

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerImplCopyWith<_$ServerImpl> get copyWith =>
      __$$ServerImplCopyWithImpl<_$ServerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerImplToJson(this);
  }
}

abstract class _Server extends Server {
  const factory _Server({final Team team, final PlayerPosition position}) =
      _$ServerImpl;
  const _Server._() : super._();

  factory _Server.fromJson(Map<String, dynamic> json) = _$ServerImpl.fromJson;

  /// Equipo que tiene el servicio
  @override
  Team get team;

  /// Posición del jugador que saca (drive o revés)
  @override
  PlayerPosition get position;

  /// Create a copy of Server
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServerImplCopyWith<_$ServerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatchSettings _$MatchSettingsFromJson(Map<String, dynamic> json) {
  return _MatchSettings.fromJson(json);
}

/// @nodoc
mixin _$MatchSettings {
  /// Número de sets para ganar el partido (normalmente 2)
  int get setsToWin => throw _privateConstructorUsedError;

  /// Juegos para llegar al tie-break:
  /// - 6: Tie-break normal a 7 puntos cuando se llega a 6-6 en games
  /// - 1: Super Tie-Break a 10 puntos en el tercer set (en lugar de jugar un set completo)
  int get tieBreakAtGames => throw _privateConstructorUsedError;

  /// Punto de oro en 40-40 (deuce)
  /// - true: En 40-40, el siguiente punto decide el juego (punto de oro)
  /// - false: En 40-40, hay que ganar por diferencia de 2 puntos (ventaja/desventaja)
  bool get goldenPoint => throw _privateConstructorUsedError;

  /// Puntos objetivo para ganar un tie-break (siempre con diferencia de 2):
  /// - 7: Para tie-breaks normales en 6-6
  /// - 10: Para Super Tie-Break en el tercer set
  int get tieBreakTarget => throw _privateConstructorUsedError;

  /// Modo de partido: Amateur o Campeonato
  /// - Amateur: Sets 5-5 se deciden con diferencia de 2, máximo 9-8
  /// - Campeonato: Sets 5-5 → tie break a 7, empate 1-1 → Super tie break a 11
  MatchMode get matchMode => throw _privateConstructorUsedError;

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
    MatchMode matchMode,
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
    Object? matchMode = null,
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
            matchMode:
                null == matchMode
                    ? _value.matchMode
                    : matchMode // ignore: cast_nullable_to_non_nullable
                        as MatchMode,
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
    MatchMode matchMode,
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
    Object? matchMode = null,
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
        matchMode:
            null == matchMode
                ? _value.matchMode
                : matchMode // ignore: cast_nullable_to_non_nullable
                    as MatchMode,
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
    this.matchMode = MatchMode.amateur,
  });

  factory _$MatchSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchSettingsImplFromJson(json);

  /// Número de sets para ganar el partido (normalmente 2)
  @override
  @JsonKey()
  final int setsToWin;

  /// Juegos para llegar al tie-break:
  /// - 6: Tie-break normal a 7 puntos cuando se llega a 6-6 en games
  /// - 1: Super Tie-Break a 10 puntos en el tercer set (en lugar de jugar un set completo)
  @override
  @JsonKey()
  final int tieBreakAtGames;

  /// Punto de oro en 40-40 (deuce)
  /// - true: En 40-40, el siguiente punto decide el juego (punto de oro)
  /// - false: En 40-40, hay que ganar por diferencia de 2 puntos (ventaja/desventaja)
  @override
  @JsonKey()
  final bool goldenPoint;

  /// Puntos objetivo para ganar un tie-break (siempre con diferencia de 2):
  /// - 7: Para tie-breaks normales en 6-6
  /// - 10: Para Super Tie-Break en el tercer set
  @override
  @JsonKey()
  final int tieBreakTarget;

  /// Modo de partido: Amateur o Campeonato
  /// - Amateur: Sets 5-5 se deciden con diferencia de 2, máximo 9-8
  /// - Campeonato: Sets 5-5 → tie break a 7, empate 1-1 → Super tie break a 11
  @override
  @JsonKey()
  final MatchMode matchMode;

  @override
  String toString() {
    return 'MatchSettings(setsToWin: $setsToWin, tieBreakAtGames: $tieBreakAtGames, goldenPoint: $goldenPoint, tieBreakTarget: $tieBreakTarget, matchMode: $matchMode)';
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
                other.tieBreakTarget == tieBreakTarget) &&
            (identical(other.matchMode, matchMode) ||
                other.matchMode == matchMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    setsToWin,
    tieBreakAtGames,
    goldenPoint,
    tieBreakTarget,
    matchMode,
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
    final MatchMode matchMode,
  }) = _$MatchSettingsImpl;

  factory _MatchSettings.fromJson(Map<String, dynamic> json) =
      _$MatchSettingsImpl.fromJson;

  /// Número de sets para ganar el partido (normalmente 2)
  @override
  int get setsToWin;

  /// Juegos para llegar al tie-break:
  /// - 6: Tie-break normal a 7 puntos cuando se llega a 6-6 en games
  /// - 1: Super Tie-Break a 10 puntos en el tercer set (en lugar de jugar un set completo)
  @override
  int get tieBreakAtGames;

  /// Punto de oro en 40-40 (deuce)
  /// - true: En 40-40, el siguiente punto decide el juego (punto de oro)
  /// - false: En 40-40, hay que ganar por diferencia de 2 puntos (ventaja/desventaja)
  @override
  bool get goldenPoint;

  /// Puntos objetivo para ganar un tie-break (siempre con diferencia de 2):
  /// - 7: Para tie-breaks normales en 6-6
  /// - 10: Para Super Tie-Break en el tercer set
  @override
  int get tieBreakTarget;

  /// Modo de partido: Amateur o Campeonato
  /// - Amateur: Sets 5-5 se deciden con diferencia de 2, máximo 9-8
  /// - Campeonato: Sets 5-5 → tie break a 7, empate 1-1 → Super tie break a 11
  @override
  MatchMode get matchMode;

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
  /// Puntos del equipo verde en el juego actual
  int get blue => throw _privateConstructorUsedError;

  /// Puntos del equipo negro en el juego actual
  int get red => throw _privateConstructorUsedError;

  /// Indica si el juego actual es un tie-break
  /// - true: Conteo 1,2,3,... hasta llegar al objetivo (7 o 10)
  /// - false: Conteo 0,15,30,40,AD en juegos normales
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

  /// Puntos del equipo verde en el juego actual
  @override
  @JsonKey()
  final int blue;

  /// Puntos del equipo negro en el juego actual
  @override
  @JsonKey()
  final int red;

  /// Indica si el juego actual es un tie-break
  /// - true: Conteo 1,2,3,... hasta llegar al objetivo (7 o 10)
  /// - false: Conteo 0,15,30,40,AD en juegos normales
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

  /// Puntos del equipo verde en el juego actual
  @override
  int get blue;

  /// Puntos del equipo negro en el juego actual
  @override
  int get red;

  /// Indica si el juego actual es un tie-break
  /// - true: Conteo 1,2,3,... hasta llegar al objetivo (7 o 10)
  /// - false: Conteo 0,15,30,40,AD en juegos normales
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
  /// Juegos ganados por el equipo verde en este set
  int get blueGames => throw _privateConstructorUsedError;

  /// Juegos ganados por el equipo negro en este set
  int get redGames => throw _privateConstructorUsedError;

  /// Puntos del juego actual dentro del set
  GamePoints get currentGame => throw _privateConstructorUsedError;

  /// Servidor que comenzó el tie-break (para la rotación 1–2–2–2)
  /// En tie-breaks, el servicio rota después de cada punto
  Server? get tieBreakStartServer => throw _privateConstructorUsedError;

  /// @deprecated Mantener por compatibilidad con Team
  Team? get tieBreakStarter => throw _privateConstructorUsedError;

  /// Indica si este set es un Super Tie-Break (a 10/11 puntos)
  /// - true: Es un Super Tie-Break (tercer set en formato campeonato o tradicional)
  /// - false: Es un set normal (con tie-break regular a 7 puntos)
  bool get isSuperTieBreak => throw _privateConstructorUsedError;

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
    Server? tieBreakStartServer,
    Team? tieBreakStarter,
    bool isSuperTieBreak,
  });

  $GamePointsCopyWith<$Res> get currentGame;
  $ServerCopyWith<$Res>? get tieBreakStartServer;
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
    Object? tieBreakStartServer = freezed,
    Object? tieBreakStarter = freezed,
    Object? isSuperTieBreak = null,
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
            tieBreakStartServer:
                freezed == tieBreakStartServer
                    ? _value.tieBreakStartServer
                    : tieBreakStartServer // ignore: cast_nullable_to_non_nullable
                        as Server?,
            tieBreakStarter:
                freezed == tieBreakStarter
                    ? _value.tieBreakStarter
                    : tieBreakStarter // ignore: cast_nullable_to_non_nullable
                        as Team?,
            isSuperTieBreak:
                null == isSuperTieBreak
                    ? _value.isSuperTieBreak
                    : isSuperTieBreak // ignore: cast_nullable_to_non_nullable
                        as bool,
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

  /// Create a copy of SetScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ServerCopyWith<$Res>? get tieBreakStartServer {
    if (_value.tieBreakStartServer == null) {
      return null;
    }

    return $ServerCopyWith<$Res>(_value.tieBreakStartServer!, (value) {
      return _then(_value.copyWith(tieBreakStartServer: value) as $Val);
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
    Server? tieBreakStartServer,
    Team? tieBreakStarter,
    bool isSuperTieBreak,
  });

  @override
  $GamePointsCopyWith<$Res> get currentGame;
  @override
  $ServerCopyWith<$Res>? get tieBreakStartServer;
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
    Object? tieBreakStartServer = freezed,
    Object? tieBreakStarter = freezed,
    Object? isSuperTieBreak = null,
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
        tieBreakStartServer:
            freezed == tieBreakStartServer
                ? _value.tieBreakStartServer
                : tieBreakStartServer // ignore: cast_nullable_to_non_nullable
                    as Server?,
        tieBreakStarter:
            freezed == tieBreakStarter
                ? _value.tieBreakStarter
                : tieBreakStarter // ignore: cast_nullable_to_non_nullable
                    as Team?,
        isSuperTieBreak:
            null == isSuperTieBreak
                ? _value.isSuperTieBreak
                : isSuperTieBreak // ignore: cast_nullable_to_non_nullable
                    as bool,
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
    this.tieBreakStartServer,
    this.tieBreakStarter,
    this.isSuperTieBreak = false,
  });

  factory _$SetScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$SetScoreImplFromJson(json);

  /// Juegos ganados por el equipo verde en este set
  @override
  @JsonKey()
  final int blueGames;

  /// Juegos ganados por el equipo negro en este set
  @override
  @JsonKey()
  final int redGames;

  /// Puntos del juego actual dentro del set
  @override
  @JsonKey()
  final GamePoints currentGame;

  /// Servidor que comenzó el tie-break (para la rotación 1–2–2–2)
  /// En tie-breaks, el servicio rota después de cada punto
  @override
  final Server? tieBreakStartServer;

  /// @deprecated Mantener por compatibilidad con Team
  @override
  final Team? tieBreakStarter;

  /// Indica si este set es un Super Tie-Break (a 10/11 puntos)
  /// - true: Es un Super Tie-Break (tercer set en formato campeonato o tradicional)
  /// - false: Es un set normal (con tie-break regular a 7 puntos)
  @override
  @JsonKey()
  final bool isSuperTieBreak;

  @override
  String toString() {
    return 'SetScore(blueGames: $blueGames, redGames: $redGames, currentGame: $currentGame, tieBreakStartServer: $tieBreakStartServer, tieBreakStarter: $tieBreakStarter, isSuperTieBreak: $isSuperTieBreak)';
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
            (identical(other.tieBreakStartServer, tieBreakStartServer) ||
                other.tieBreakStartServer == tieBreakStartServer) &&
            (identical(other.tieBreakStarter, tieBreakStarter) ||
                other.tieBreakStarter == tieBreakStarter) &&
            (identical(other.isSuperTieBreak, isSuperTieBreak) ||
                other.isSuperTieBreak == isSuperTieBreak));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    blueGames,
    redGames,
    currentGame,
    tieBreakStartServer,
    tieBreakStarter,
    isSuperTieBreak,
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
    final Server? tieBreakStartServer,
    final Team? tieBreakStarter,
    final bool isSuperTieBreak,
  }) = _$SetScoreImpl;

  factory _SetScore.fromJson(Map<String, dynamic> json) =
      _$SetScoreImpl.fromJson;

  /// Juegos ganados por el equipo verde en este set
  @override
  int get blueGames;

  /// Juegos ganados por el equipo negro en este set
  @override
  int get redGames;

  /// Puntos del juego actual dentro del set
  @override
  GamePoints get currentGame;

  /// Servidor que comenzó el tie-break (para la rotación 1–2–2–2)
  /// En tie-breaks, el servicio rota después de cada punto
  @override
  Server? get tieBreakStartServer;

  /// @deprecated Mantener por compatibilidad con Team
  @override
  Team? get tieBreakStarter;

  /// Indica si este set es un Super Tie-Break (a 10/11 puntos)
  /// - true: Es un Super Tie-Break (tercer set en formato campeonato o tradicional)
  /// - false: Es un set normal (con tie-break regular a 7 puntos)
  @override
  bool get isSuperTieBreak;

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
  /// Lista de todos los sets del partido
  List<SetScore> get sets => throw _privateConstructorUsedError;

  /// Índice del set actual (0 = primer set, 1 = segundo set, 2 = tercer set)
  int get currentSetIndex => throw _privateConstructorUsedError;

  /// Servidor actual: equipo + posición (drive/revés)
  /// Rotación: DRY1 → DRY2 → REVÉS1 → REVÉS2 → repite
  Server get currentServer => throw _privateConstructorUsedError;

  /// @deprecated Mantener por compatibilidad - usar currentServer.team
  Team get server => throw _privateConstructorUsedError;

  /// @deprecated Mantener por compatibilidad
  Team get receiver => throw _privateConstructorUsedError;

  /// Nombre del equipo verde
  String get blueName => throw _privateConstructorUsedError;

  /// Nombre del equipo negro
  String get redName => throw _privateConstructorUsedError;

  /// Indica si el partido está en pausa
  bool get paused => throw _privateConstructorUsedError;

  /// Configuración del partido
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
    Server currentServer,
    Team server,
    Team receiver,
    String blueName,
    String redName,
    bool paused,
    MatchSettings settings,
  });

  $ServerCopyWith<$Res> get currentServer;
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
    Object? currentServer = null,
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
            currentServer:
                null == currentServer
                    ? _value.currentServer
                    : currentServer // ignore: cast_nullable_to_non_nullable
                        as Server,
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
  $ServerCopyWith<$Res> get currentServer {
    return $ServerCopyWith<$Res>(_value.currentServer, (value) {
      return _then(_value.copyWith(currentServer: value) as $Val);
    });
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
    Server currentServer,
    Team server,
    Team receiver,
    String blueName,
    String redName,
    bool paused,
    MatchSettings settings,
  });

  @override
  $ServerCopyWith<$Res> get currentServer;
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
    Object? currentServer = null,
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
        currentServer:
            null == currentServer
                ? _value.currentServer
                : currentServer // ignore: cast_nullable_to_non_nullable
                    as Server,
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
class _$MatchScoreImpl extends _MatchScore {
  const _$MatchScoreImpl({
    final List<SetScore> sets = const <SetScore>[],
    this.currentSetIndex = 0,
    this.currentServer = const Server(),
    this.server = Team.blue,
    this.receiver = Team.red,
    this.blueName = 'Verde',
    this.redName = 'Negro',
    this.paused = false,
    this.settings = const MatchSettings(),
  }) : _sets = sets,
       super._();

  factory _$MatchScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchScoreImplFromJson(json);

  /// Lista de todos los sets del partido
  final List<SetScore> _sets;

  /// Lista de todos los sets del partido
  @override
  @JsonKey()
  List<SetScore> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  /// Índice del set actual (0 = primer set, 1 = segundo set, 2 = tercer set)
  @override
  @JsonKey()
  final int currentSetIndex;

  /// Servidor actual: equipo + posición (drive/revés)
  /// Rotación: DRY1 → DRY2 → REVÉS1 → REVÉS2 → repite
  @override
  @JsonKey()
  final Server currentServer;

  /// @deprecated Mantener por compatibilidad - usar currentServer.team
  @override
  @JsonKey()
  final Team server;

  /// @deprecated Mantener por compatibilidad
  @override
  @JsonKey()
  final Team receiver;

  /// Nombre del equipo verde
  @override
  @JsonKey()
  final String blueName;

  /// Nombre del equipo negro
  @override
  @JsonKey()
  final String redName;

  /// Indica si el partido está en pausa
  @override
  @JsonKey()
  final bool paused;

  /// Configuración del partido
  @override
  @JsonKey()
  final MatchSettings settings;

  @override
  String toString() {
    return 'MatchScore(sets: $sets, currentSetIndex: $currentSetIndex, currentServer: $currentServer, server: $server, receiver: $receiver, blueName: $blueName, redName: $redName, paused: $paused, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchScoreImpl &&
            const DeepCollectionEquality().equals(other._sets, _sets) &&
            (identical(other.currentSetIndex, currentSetIndex) ||
                other.currentSetIndex == currentSetIndex) &&
            (identical(other.currentServer, currentServer) ||
                other.currentServer == currentServer) &&
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
    currentServer,
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
    final Server currentServer,
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

  /// Lista de todos los sets del partido
  @override
  List<SetScore> get sets;

  /// Índice del set actual (0 = primer set, 1 = segundo set, 2 = tercer set)
  @override
  int get currentSetIndex;

  /// Servidor actual: equipo + posición (drive/revés)
  /// Rotación: DRY1 → DRY2 → REVÉS1 → REVÉS2 → repite
  @override
  Server get currentServer;

  /// @deprecated Mantener por compatibilidad - usar currentServer.team
  @override
  Team get server;

  /// @deprecated Mantener por compatibilidad
  @override
  Team get receiver;

  /// Nombre del equipo verde
  @override
  String get blueName;

  /// Nombre del equipo negro
  @override
  String get redName;

  /// Indica si el partido está en pausa
  @override
  bool get paused;

  /// Configuración del partido
  @override
  MatchSettings get settings;

  /// Create a copy of MatchScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchScoreImplCopyWith<_$MatchScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
