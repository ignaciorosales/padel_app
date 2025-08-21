// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scoring_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ScoringEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScoringEventCopyWith<$Res> {
  factory $ScoringEventCopyWith(
    ScoringEvent value,
    $Res Function(ScoringEvent) then,
  ) = _$ScoringEventCopyWithImpl<$Res, ScoringEvent>;
}

/// @nodoc
class _$ScoringEventCopyWithImpl<$Res, $Val extends ScoringEvent>
    implements $ScoringEventCopyWith<$Res> {
  _$ScoringEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$NewMatchEventImplCopyWith<$Res> {
  factory _$$NewMatchEventImplCopyWith(
    _$NewMatchEventImpl value,
    $Res Function(_$NewMatchEventImpl) then,
  ) = __$$NewMatchEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MatchSettings? settings, Team? startingServer});

  $MatchSettingsCopyWith<$Res>? get settings;
}

/// @nodoc
class __$$NewMatchEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$NewMatchEventImpl>
    implements _$$NewMatchEventImplCopyWith<$Res> {
  __$$NewMatchEventImplCopyWithImpl(
    _$NewMatchEventImpl _value,
    $Res Function(_$NewMatchEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? settings = freezed, Object? startingServer = freezed}) {
    return _then(
      _$NewMatchEventImpl(
        settings:
            freezed == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                    as MatchSettings?,
        startingServer:
            freezed == startingServer
                ? _value.startingServer
                : startingServer // ignore: cast_nullable_to_non_nullable
                    as Team?,
      ),
    );
  }

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MatchSettingsCopyWith<$Res>? get settings {
    if (_value.settings == null) {
      return null;
    }

    return $MatchSettingsCopyWith<$Res>(_value.settings!, (value) {
      return _then(_value.copyWith(settings: value));
    });
  }
}

/// @nodoc

class _$NewMatchEventImpl implements NewMatchEvent {
  const _$NewMatchEventImpl({this.settings, this.startingServer});

  @override
  final MatchSettings? settings;
  @override
  final Team? startingServer;

  @override
  String toString() {
    return 'ScoringEvent.newMatch(settings: $settings, startingServer: $startingServer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NewMatchEventImpl &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.startingServer, startingServer) ||
                other.startingServer == startingServer));
  }

  @override
  int get hashCode => Object.hash(runtimeType, settings, startingServer);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NewMatchEventImplCopyWith<_$NewMatchEventImpl> get copyWith =>
      __$$NewMatchEventImplCopyWithImpl<_$NewMatchEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return newMatch(settings, startingServer);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return newMatch?.call(settings, startingServer);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (newMatch != null) {
      return newMatch(settings, startingServer);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return newMatch(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return newMatch?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (newMatch != null) {
      return newMatch(this);
    }
    return orElse();
  }
}

abstract class NewMatchEvent implements ScoringEvent {
  const factory NewMatchEvent({
    final MatchSettings? settings,
    final Team? startingServer,
  }) = _$NewMatchEventImpl;

  MatchSettings? get settings;
  Team? get startingServer;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NewMatchEventImplCopyWith<_$NewMatchEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NewSetEventImplCopyWith<$Res> {
  factory _$$NewSetEventImplCopyWith(
    _$NewSetEventImpl value,
    $Res Function(_$NewSetEventImpl) then,
  ) = __$$NewSetEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NewSetEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$NewSetEventImpl>
    implements _$$NewSetEventImplCopyWith<$Res> {
  __$$NewSetEventImplCopyWithImpl(
    _$NewSetEventImpl _value,
    $Res Function(_$NewSetEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NewSetEventImpl implements NewSetEvent {
  const _$NewSetEventImpl();

  @override
  String toString() {
    return 'ScoringEvent.newSet()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$NewSetEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return newSet();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return newSet?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (newSet != null) {
      return newSet();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return newSet(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return newSet?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (newSet != null) {
      return newSet(this);
    }
    return orElse();
  }
}

abstract class NewSetEvent implements ScoringEvent {
  const factory NewSetEvent() = _$NewSetEventImpl;
}

/// @nodoc
abstract class _$$NewGameEventImplCopyWith<$Res> {
  factory _$$NewGameEventImplCopyWith(
    _$NewGameEventImpl value,
    $Res Function(_$NewGameEventImpl) then,
  ) = __$$NewGameEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NewGameEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$NewGameEventImpl>
    implements _$$NewGameEventImplCopyWith<$Res> {
  __$$NewGameEventImplCopyWithImpl(
    _$NewGameEventImpl _value,
    $Res Function(_$NewGameEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NewGameEventImpl implements NewGameEvent {
  const _$NewGameEventImpl();

  @override
  String toString() {
    return 'ScoringEvent.newGame()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$NewGameEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return newGame();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return newGame?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (newGame != null) {
      return newGame();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return newGame(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return newGame?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (newGame != null) {
      return newGame(this);
    }
    return orElse();
  }
}

abstract class NewGameEvent implements ScoringEvent {
  const factory NewGameEvent() = _$NewGameEventImpl;
}

/// @nodoc
abstract class _$$PointForEventImplCopyWith<$Res> {
  factory _$$PointForEventImplCopyWith(
    _$PointForEventImpl value,
    $Res Function(_$PointForEventImpl) then,
  ) = __$$PointForEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Team team});
}

/// @nodoc
class __$$PointForEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$PointForEventImpl>
    implements _$$PointForEventImplCopyWith<$Res> {
  __$$PointForEventImplCopyWithImpl(
    _$PointForEventImpl _value,
    $Res Function(_$PointForEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null}) {
    return _then(
      _$PointForEventImpl(
        null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                as Team,
      ),
    );
  }
}

/// @nodoc

class _$PointForEventImpl implements PointForEvent {
  const _$PointForEventImpl(this.team);

  @override
  final Team team;

  @override
  String toString() {
    return 'ScoringEvent.pointFor(team: $team)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PointForEventImpl &&
            (identical(other.team, team) || other.team == team));
  }

  @override
  int get hashCode => Object.hash(runtimeType, team);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PointForEventImplCopyWith<_$PointForEventImpl> get copyWith =>
      __$$PointForEventImplCopyWithImpl<_$PointForEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return pointFor(team);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return pointFor?.call(team);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (pointFor != null) {
      return pointFor(team);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return pointFor(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return pointFor?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (pointFor != null) {
      return pointFor(this);
    }
    return orElse();
  }
}

abstract class PointForEvent implements ScoringEvent {
  const factory PointForEvent(final Team team) = _$PointForEventImpl;

  Team get team;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PointForEventImplCopyWith<_$PointForEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RemovePointEventImplCopyWith<$Res> {
  factory _$$RemovePointEventImplCopyWith(
    _$RemovePointEventImpl value,
    $Res Function(_$RemovePointEventImpl) then,
  ) = __$$RemovePointEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Team team});
}

/// @nodoc
class __$$RemovePointEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$RemovePointEventImpl>
    implements _$$RemovePointEventImplCopyWith<$Res> {
  __$$RemovePointEventImplCopyWithImpl(
    _$RemovePointEventImpl _value,
    $Res Function(_$RemovePointEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null}) {
    return _then(
      _$RemovePointEventImpl(
        null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                as Team,
      ),
    );
  }
}

/// @nodoc

class _$RemovePointEventImpl implements RemovePointEvent {
  const _$RemovePointEventImpl(this.team);

  @override
  final Team team;

  @override
  String toString() {
    return 'ScoringEvent.removePoint(team: $team)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemovePointEventImpl &&
            (identical(other.team, team) || other.team == team));
  }

  @override
  int get hashCode => Object.hash(runtimeType, team);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemovePointEventImplCopyWith<_$RemovePointEventImpl> get copyWith =>
      __$$RemovePointEventImplCopyWithImpl<_$RemovePointEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return removePoint(team);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return removePoint?.call(team);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (removePoint != null) {
      return removePoint(team);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return removePoint(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return removePoint?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (removePoint != null) {
      return removePoint(this);
    }
    return orElse();
  }
}

abstract class RemovePointEvent implements ScoringEvent {
  const factory RemovePointEvent(final Team team) = _$RemovePointEventImpl;

  Team get team;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemovePointEventImplCopyWith<_$RemovePointEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ForceGameForEventImplCopyWith<$Res> {
  factory _$$ForceGameForEventImplCopyWith(
    _$ForceGameForEventImpl value,
    $Res Function(_$ForceGameForEventImpl) then,
  ) = __$$ForceGameForEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Team team});
}

/// @nodoc
class __$$ForceGameForEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$ForceGameForEventImpl>
    implements _$$ForceGameForEventImplCopyWith<$Res> {
  __$$ForceGameForEventImplCopyWithImpl(
    _$ForceGameForEventImpl _value,
    $Res Function(_$ForceGameForEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null}) {
    return _then(
      _$ForceGameForEventImpl(
        null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                as Team,
      ),
    );
  }
}

/// @nodoc

class _$ForceGameForEventImpl implements ForceGameForEvent {
  const _$ForceGameForEventImpl(this.team);

  @override
  final Team team;

  @override
  String toString() {
    return 'ScoringEvent.forceGameFor(team: $team)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForceGameForEventImpl &&
            (identical(other.team, team) || other.team == team));
  }

  @override
  int get hashCode => Object.hash(runtimeType, team);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForceGameForEventImplCopyWith<_$ForceGameForEventImpl> get copyWith =>
      __$$ForceGameForEventImplCopyWithImpl<_$ForceGameForEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return forceGameFor(team);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return forceGameFor?.call(team);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (forceGameFor != null) {
      return forceGameFor(team);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return forceGameFor(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return forceGameFor?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (forceGameFor != null) {
      return forceGameFor(this);
    }
    return orElse();
  }
}

abstract class ForceGameForEvent implements ScoringEvent {
  const factory ForceGameForEvent(final Team team) = _$ForceGameForEventImpl;

  Team get team;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForceGameForEventImplCopyWith<_$ForceGameForEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ForceSetForEventImplCopyWith<$Res> {
  factory _$$ForceSetForEventImplCopyWith(
    _$ForceSetForEventImpl value,
    $Res Function(_$ForceSetForEventImpl) then,
  ) = __$$ForceSetForEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Team team});
}

/// @nodoc
class __$$ForceSetForEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$ForceSetForEventImpl>
    implements _$$ForceSetForEventImplCopyWith<$Res> {
  __$$ForceSetForEventImplCopyWithImpl(
    _$ForceSetForEventImpl _value,
    $Res Function(_$ForceSetForEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null}) {
    return _then(
      _$ForceSetForEventImpl(
        null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                as Team,
      ),
    );
  }
}

/// @nodoc

class _$ForceSetForEventImpl implements ForceSetForEvent {
  const _$ForceSetForEventImpl(this.team);

  @override
  final Team team;

  @override
  String toString() {
    return 'ScoringEvent.forceSetFor(team: $team)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForceSetForEventImpl &&
            (identical(other.team, team) || other.team == team));
  }

  @override
  int get hashCode => Object.hash(runtimeType, team);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForceSetForEventImplCopyWith<_$ForceSetForEventImpl> get copyWith =>
      __$$ForceSetForEventImplCopyWithImpl<_$ForceSetForEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return forceSetFor(team);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return forceSetFor?.call(team);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (forceSetFor != null) {
      return forceSetFor(team);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return forceSetFor(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return forceSetFor?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (forceSetFor != null) {
      return forceSetFor(this);
    }
    return orElse();
  }
}

abstract class ForceSetForEvent implements ScoringEvent {
  const factory ForceSetForEvent(final Team team) = _$ForceSetForEventImpl;

  Team get team;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForceSetForEventImplCopyWith<_$ForceSetForEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SetExplicitGamePointsEventImplCopyWith<$Res> {
  factory _$$SetExplicitGamePointsEventImplCopyWith(
    _$SetExplicitGamePointsEventImpl value,
    $Res Function(_$SetExplicitGamePointsEventImpl) then,
  ) = __$$SetExplicitGamePointsEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int blue, int red});
}

/// @nodoc
class __$$SetExplicitGamePointsEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$SetExplicitGamePointsEventImpl>
    implements _$$SetExplicitGamePointsEventImplCopyWith<$Res> {
  __$$SetExplicitGamePointsEventImplCopyWithImpl(
    _$SetExplicitGamePointsEventImpl _value,
    $Res Function(_$SetExplicitGamePointsEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? blue = null, Object? red = null}) {
    return _then(
      _$SetExplicitGamePointsEventImpl(
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
      ),
    );
  }
}

/// @nodoc

class _$SetExplicitGamePointsEventImpl implements SetExplicitGamePointsEvent {
  const _$SetExplicitGamePointsEventImpl({
    required this.blue,
    required this.red,
  });

  @override
  final int blue;
  @override
  final int red;

  @override
  String toString() {
    return 'ScoringEvent.setExplicitGamePoints(blue: $blue, red: $red)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetExplicitGamePointsEventImpl &&
            (identical(other.blue, blue) || other.blue == blue) &&
            (identical(other.red, red) || other.red == red));
  }

  @override
  int get hashCode => Object.hash(runtimeType, blue, red);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SetExplicitGamePointsEventImplCopyWith<_$SetExplicitGamePointsEventImpl>
  get copyWith => __$$SetExplicitGamePointsEventImplCopyWithImpl<
    _$SetExplicitGamePointsEventImpl
  >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return setExplicitGamePoints(blue, red);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return setExplicitGamePoints?.call(blue, red);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (setExplicitGamePoints != null) {
      return setExplicitGamePoints(blue, red);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return setExplicitGamePoints(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return setExplicitGamePoints?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (setExplicitGamePoints != null) {
      return setExplicitGamePoints(this);
    }
    return orElse();
  }
}

abstract class SetExplicitGamePointsEvent implements ScoringEvent {
  const factory SetExplicitGamePointsEvent({
    required final int blue,
    required final int red,
  }) = _$SetExplicitGamePointsEventImpl;

  int get blue;
  int get red;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetExplicitGamePointsEventImplCopyWith<_$SetExplicitGamePointsEventImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ToggleTieBreakGamesEventImplCopyWith<$Res> {
  factory _$$ToggleTieBreakGamesEventImplCopyWith(
    _$ToggleTieBreakGamesEventImpl value,
    $Res Function(_$ToggleTieBreakGamesEventImpl) then,
  ) = __$$ToggleTieBreakGamesEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int games});
}

/// @nodoc
class __$$ToggleTieBreakGamesEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$ToggleTieBreakGamesEventImpl>
    implements _$$ToggleTieBreakGamesEventImplCopyWith<$Res> {
  __$$ToggleTieBreakGamesEventImplCopyWithImpl(
    _$ToggleTieBreakGamesEventImpl _value,
    $Res Function(_$ToggleTieBreakGamesEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? games = null}) {
    return _then(
      _$ToggleTieBreakGamesEventImpl(
        null == games
            ? _value.games
            : games // ignore: cast_nullable_to_non_nullable
                as int,
      ),
    );
  }
}

/// @nodoc

class _$ToggleTieBreakGamesEventImpl implements ToggleTieBreakGamesEvent {
  const _$ToggleTieBreakGamesEventImpl(this.games);

  @override
  final int games;

  @override
  String toString() {
    return 'ScoringEvent.toggleTieBreakGames(games: $games)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToggleTieBreakGamesEventImpl &&
            (identical(other.games, games) || other.games == games));
  }

  @override
  int get hashCode => Object.hash(runtimeType, games);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToggleTieBreakGamesEventImplCopyWith<_$ToggleTieBreakGamesEventImpl>
  get copyWith => __$$ToggleTieBreakGamesEventImplCopyWithImpl<
    _$ToggleTieBreakGamesEventImpl
  >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return toggleTieBreakGames(games);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return toggleTieBreakGames?.call(games);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (toggleTieBreakGames != null) {
      return toggleTieBreakGames(games);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return toggleTieBreakGames(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return toggleTieBreakGames?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (toggleTieBreakGames != null) {
      return toggleTieBreakGames(this);
    }
    return orElse();
  }
}

abstract class ToggleTieBreakGamesEvent implements ScoringEvent {
  const factory ToggleTieBreakGamesEvent(final int games) =
      _$ToggleTieBreakGamesEventImpl;

  int get games;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToggleTieBreakGamesEventImplCopyWith<_$ToggleTieBreakGamesEventImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ToggleGoldenPointEventImplCopyWith<$Res> {
  factory _$$ToggleGoldenPointEventImplCopyWith(
    _$ToggleGoldenPointEventImpl value,
    $Res Function(_$ToggleGoldenPointEventImpl) then,
  ) = __$$ToggleGoldenPointEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool enabled});
}

/// @nodoc
class __$$ToggleGoldenPointEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$ToggleGoldenPointEventImpl>
    implements _$$ToggleGoldenPointEventImplCopyWith<$Res> {
  __$$ToggleGoldenPointEventImplCopyWithImpl(
    _$ToggleGoldenPointEventImpl _value,
    $Res Function(_$ToggleGoldenPointEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? enabled = null}) {
    return _then(
      _$ToggleGoldenPointEventImpl(
        null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                as bool,
      ),
    );
  }
}

/// @nodoc

class _$ToggleGoldenPointEventImpl implements ToggleGoldenPointEvent {
  const _$ToggleGoldenPointEventImpl(this.enabled);

  @override
  final bool enabled;

  @override
  String toString() {
    return 'ScoringEvent.toggleGoldenPoint(enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToggleGoldenPointEventImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, enabled);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToggleGoldenPointEventImplCopyWith<_$ToggleGoldenPointEventImpl>
  get copyWith =>
      __$$ToggleGoldenPointEventImplCopyWithImpl<_$ToggleGoldenPointEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return toggleGoldenPoint(enabled);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return toggleGoldenPoint?.call(enabled);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (toggleGoldenPoint != null) {
      return toggleGoldenPoint(enabled);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return toggleGoldenPoint(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return toggleGoldenPoint?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (toggleGoldenPoint != null) {
      return toggleGoldenPoint(this);
    }
    return orElse();
  }
}

abstract class ToggleGoldenPointEvent implements ScoringEvent {
  const factory ToggleGoldenPointEvent(final bool enabled) =
      _$ToggleGoldenPointEventImpl;

  bool get enabled;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToggleGoldenPointEventImplCopyWith<_$ToggleGoldenPointEventImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AnnounceScoreEventImplCopyWith<$Res> {
  factory _$$AnnounceScoreEventImplCopyWith(
    _$AnnounceScoreEventImpl value,
    $Res Function(_$AnnounceScoreEventImpl) then,
  ) = __$$AnnounceScoreEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$AnnounceScoreEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$AnnounceScoreEventImpl>
    implements _$$AnnounceScoreEventImplCopyWith<$Res> {
  __$$AnnounceScoreEventImplCopyWithImpl(
    _$AnnounceScoreEventImpl _value,
    $Res Function(_$AnnounceScoreEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$AnnounceScoreEventImpl implements AnnounceScoreEvent {
  const _$AnnounceScoreEventImpl();

  @override
  String toString() {
    return 'ScoringEvent.announceScore()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$AnnounceScoreEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return announceScore();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return announceScore?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (announceScore != null) {
      return announceScore();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return announceScore(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return announceScore?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (announceScore != null) {
      return announceScore(this);
    }
    return orElse();
  }
}

abstract class AnnounceScoreEvent implements ScoringEvent {
  const factory AnnounceScoreEvent() = _$AnnounceScoreEventImpl;
}

/// @nodoc
abstract class _$$UndoEventImplCopyWith<$Res> {
  factory _$$UndoEventImplCopyWith(
    _$UndoEventImpl value,
    $Res Function(_$UndoEventImpl) then,
  ) = __$$UndoEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$UndoEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$UndoEventImpl>
    implements _$$UndoEventImplCopyWith<$Res> {
  __$$UndoEventImplCopyWithImpl(
    _$UndoEventImpl _value,
    $Res Function(_$UndoEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$UndoEventImpl implements UndoEvent {
  const _$UndoEventImpl();

  @override
  String toString() {
    return 'ScoringEvent.undo()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$UndoEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return undo();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return undo?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (undo != null) {
      return undo();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return undo(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return undo?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (undo != null) {
      return undo(this);
    }
    return orElse();
  }
}

abstract class UndoEvent implements ScoringEvent {
  const factory UndoEvent() = _$UndoEventImpl;
}

/// @nodoc
abstract class _$$RedoEventImplCopyWith<$Res> {
  factory _$$RedoEventImplCopyWith(
    _$RedoEventImpl value,
    $Res Function(_$RedoEventImpl) then,
  ) = __$$RedoEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RedoEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$RedoEventImpl>
    implements _$$RedoEventImplCopyWith<$Res> {
  __$$RedoEventImplCopyWithImpl(
    _$RedoEventImpl _value,
    $Res Function(_$RedoEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$RedoEventImpl implements RedoEvent {
  const _$RedoEventImpl();

  @override
  String toString() {
    return 'ScoringEvent.redo()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RedoEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return redo();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return redo?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (redo != null) {
      return redo();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return redo(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return redo?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (redo != null) {
      return redo(this);
    }
    return orElse();
  }
}

abstract class RedoEvent implements ScoringEvent {
  const factory RedoEvent() = _$RedoEventImpl;
}

/// @nodoc
abstract class _$$UndoForTeamEventImplCopyWith<$Res> {
  factory _$$UndoForTeamEventImplCopyWith(
    _$UndoForTeamEventImpl value,
    $Res Function(_$UndoForTeamEventImpl) then,
  ) = __$$UndoForTeamEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Team team});
}

/// @nodoc
class __$$UndoForTeamEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$UndoForTeamEventImpl>
    implements _$$UndoForTeamEventImplCopyWith<$Res> {
  __$$UndoForTeamEventImplCopyWithImpl(
    _$UndoForTeamEventImpl _value,
    $Res Function(_$UndoForTeamEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? team = null}) {
    return _then(
      _$UndoForTeamEventImpl(
        null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                as Team,
      ),
    );
  }
}

/// @nodoc

class _$UndoForTeamEventImpl implements UndoForTeamEvent {
  const _$UndoForTeamEventImpl(this.team);

  @override
  final Team team;

  @override
  String toString() {
    return 'ScoringEvent.undoForTeam(team: $team)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UndoForTeamEventImpl &&
            (identical(other.team, team) || other.team == team));
  }

  @override
  int get hashCode => Object.hash(runtimeType, team);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UndoForTeamEventImplCopyWith<_$UndoForTeamEventImpl> get copyWith =>
      __$$UndoForTeamEventImplCopyWithImpl<_$UndoForTeamEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return undoForTeam(team);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return undoForTeam?.call(team);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (undoForTeam != null) {
      return undoForTeam(team);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return undoForTeam(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return undoForTeam?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (undoForTeam != null) {
      return undoForTeam(this);
    }
    return orElse();
  }
}

abstract class UndoForTeamEvent implements ScoringEvent {
  const factory UndoForTeamEvent(final Team team) = _$UndoForTeamEventImpl;

  Team get team;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UndoForTeamEventImplCopyWith<_$UndoForTeamEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BleCommandEventImplCopyWith<$Res> {
  factory _$$BleCommandEventImplCopyWith(
    _$BleCommandEventImpl value,
    $Res Function(_$BleCommandEventImpl) then,
  ) = __$$BleCommandEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String cmd});
}

/// @nodoc
class __$$BleCommandEventImplCopyWithImpl<$Res>
    extends _$ScoringEventCopyWithImpl<$Res, _$BleCommandEventImpl>
    implements _$$BleCommandEventImplCopyWith<$Res> {
  __$$BleCommandEventImplCopyWithImpl(
    _$BleCommandEventImpl _value,
    $Res Function(_$BleCommandEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? cmd = null}) {
    return _then(
      _$BleCommandEventImpl(
        null == cmd
            ? _value.cmd
            : cmd // ignore: cast_nullable_to_non_nullable
                as String,
      ),
    );
  }
}

/// @nodoc

class _$BleCommandEventImpl implements BleCommandEvent {
  const _$BleCommandEventImpl(this.cmd);

  @override
  final String cmd;

  @override
  String toString() {
    return 'ScoringEvent.bleCommand(cmd: $cmd)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleCommandEventImpl &&
            (identical(other.cmd, cmd) || other.cmd == cmd));
  }

  @override
  int get hashCode => Object.hash(runtimeType, cmd);

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleCommandEventImplCopyWith<_$BleCommandEventImpl> get copyWith =>
      __$$BleCommandEventImplCopyWithImpl<_$BleCommandEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MatchSettings? settings, Team? startingServer)
    newMatch,
    required TResult Function() newSet,
    required TResult Function() newGame,
    required TResult Function(Team team) pointFor,
    required TResult Function(Team team) removePoint,
    required TResult Function(Team team) forceGameFor,
    required TResult Function(Team team) forceSetFor,
    required TResult Function(int blue, int red) setExplicitGamePoints,
    required TResult Function(int games) toggleTieBreakGames,
    required TResult Function(bool enabled) toggleGoldenPoint,
    required TResult Function() announceScore,
    required TResult Function() undo,
    required TResult Function() redo,
    required TResult Function(Team team) undoForTeam,
    required TResult Function(String cmd) bleCommand,
  }) {
    return bleCommand(cmd);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult? Function()? newSet,
    TResult? Function()? newGame,
    TResult? Function(Team team)? pointFor,
    TResult? Function(Team team)? removePoint,
    TResult? Function(Team team)? forceGameFor,
    TResult? Function(Team team)? forceSetFor,
    TResult? Function(int blue, int red)? setExplicitGamePoints,
    TResult? Function(int games)? toggleTieBreakGames,
    TResult? Function(bool enabled)? toggleGoldenPoint,
    TResult? Function()? announceScore,
    TResult? Function()? undo,
    TResult? Function()? redo,
    TResult? Function(Team team)? undoForTeam,
    TResult? Function(String cmd)? bleCommand,
  }) {
    return bleCommand?.call(cmd);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MatchSettings? settings, Team? startingServer)? newMatch,
    TResult Function()? newSet,
    TResult Function()? newGame,
    TResult Function(Team team)? pointFor,
    TResult Function(Team team)? removePoint,
    TResult Function(Team team)? forceGameFor,
    TResult Function(Team team)? forceSetFor,
    TResult Function(int blue, int red)? setExplicitGamePoints,
    TResult Function(int games)? toggleTieBreakGames,
    TResult Function(bool enabled)? toggleGoldenPoint,
    TResult Function()? announceScore,
    TResult Function()? undo,
    TResult Function()? redo,
    TResult Function(Team team)? undoForTeam,
    TResult Function(String cmd)? bleCommand,
    required TResult orElse(),
  }) {
    if (bleCommand != null) {
      return bleCommand(cmd);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NewMatchEvent value) newMatch,
    required TResult Function(NewSetEvent value) newSet,
    required TResult Function(NewGameEvent value) newGame,
    required TResult Function(PointForEvent value) pointFor,
    required TResult Function(RemovePointEvent value) removePoint,
    required TResult Function(ForceGameForEvent value) forceGameFor,
    required TResult Function(ForceSetForEvent value) forceSetFor,
    required TResult Function(SetExplicitGamePointsEvent value)
    setExplicitGamePoints,
    required TResult Function(ToggleTieBreakGamesEvent value)
    toggleTieBreakGames,
    required TResult Function(ToggleGoldenPointEvent value) toggleGoldenPoint,
    required TResult Function(AnnounceScoreEvent value) announceScore,
    required TResult Function(UndoEvent value) undo,
    required TResult Function(RedoEvent value) redo,
    required TResult Function(UndoForTeamEvent value) undoForTeam,
    required TResult Function(BleCommandEvent value) bleCommand,
  }) {
    return bleCommand(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NewMatchEvent value)? newMatch,
    TResult? Function(NewSetEvent value)? newSet,
    TResult? Function(NewGameEvent value)? newGame,
    TResult? Function(PointForEvent value)? pointFor,
    TResult? Function(RemovePointEvent value)? removePoint,
    TResult? Function(ForceGameForEvent value)? forceGameFor,
    TResult? Function(ForceSetForEvent value)? forceSetFor,
    TResult? Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult? Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult? Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult? Function(AnnounceScoreEvent value)? announceScore,
    TResult? Function(UndoEvent value)? undo,
    TResult? Function(RedoEvent value)? redo,
    TResult? Function(UndoForTeamEvent value)? undoForTeam,
    TResult? Function(BleCommandEvent value)? bleCommand,
  }) {
    return bleCommand?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NewMatchEvent value)? newMatch,
    TResult Function(NewSetEvent value)? newSet,
    TResult Function(NewGameEvent value)? newGame,
    TResult Function(PointForEvent value)? pointFor,
    TResult Function(RemovePointEvent value)? removePoint,
    TResult Function(ForceGameForEvent value)? forceGameFor,
    TResult Function(ForceSetForEvent value)? forceSetFor,
    TResult Function(SetExplicitGamePointsEvent value)? setExplicitGamePoints,
    TResult Function(ToggleTieBreakGamesEvent value)? toggleTieBreakGames,
    TResult Function(ToggleGoldenPointEvent value)? toggleGoldenPoint,
    TResult Function(AnnounceScoreEvent value)? announceScore,
    TResult Function(UndoEvent value)? undo,
    TResult Function(RedoEvent value)? redo,
    TResult Function(UndoForTeamEvent value)? undoForTeam,
    TResult Function(BleCommandEvent value)? bleCommand,
    required TResult orElse(),
  }) {
    if (bleCommand != null) {
      return bleCommand(this);
    }
    return orElse();
  }
}

abstract class BleCommandEvent implements ScoringEvent {
  const factory BleCommandEvent(final String cmd) = _$BleCommandEventImpl;

  String get cmd;

  /// Create a copy of ScoringEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleCommandEventImplCopyWith<_$BleCommandEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
