// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scoring_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ScoringState {
  MatchScore get match => throw _privateConstructorUsedError;
  List<MatchScore> get undoStack => throw _privateConstructorUsedError;
  List<MatchScore> get redoStack => throw _privateConstructorUsedError;
  String get lastActionLabel => throw _privateConstructorUsedError;
  String get lastAnnouncement =>
      throw _privateConstructorUsedError; // Campos para mostrar el ganador del partido
  Team? get matchWinner => throw _privateConstructorUsedError;
  String get matchWinnerName => throw _privateConstructorUsedError;
  bool get matchCompleted => throw _privateConstructorUsedError;

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScoringStateCopyWith<ScoringState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScoringStateCopyWith<$Res> {
  factory $ScoringStateCopyWith(
    ScoringState value,
    $Res Function(ScoringState) then,
  ) = _$ScoringStateCopyWithImpl<$Res, ScoringState>;
  @useResult
  $Res call({
    MatchScore match,
    List<MatchScore> undoStack,
    List<MatchScore> redoStack,
    String lastActionLabel,
    String lastAnnouncement,
    Team? matchWinner,
    String matchWinnerName,
    bool matchCompleted,
  });

  $MatchScoreCopyWith<$Res> get match;
}

/// @nodoc
class _$ScoringStateCopyWithImpl<$Res, $Val extends ScoringState>
    implements $ScoringStateCopyWith<$Res> {
  _$ScoringStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? match = null,
    Object? undoStack = null,
    Object? redoStack = null,
    Object? lastActionLabel = null,
    Object? lastAnnouncement = null,
    Object? matchWinner = freezed,
    Object? matchWinnerName = null,
    Object? matchCompleted = null,
  }) {
    return _then(
      _value.copyWith(
            match:
                null == match
                    ? _value.match
                    : match // ignore: cast_nullable_to_non_nullable
                        as MatchScore,
            undoStack:
                null == undoStack
                    ? _value.undoStack
                    : undoStack // ignore: cast_nullable_to_non_nullable
                        as List<MatchScore>,
            redoStack:
                null == redoStack
                    ? _value.redoStack
                    : redoStack // ignore: cast_nullable_to_non_nullable
                        as List<MatchScore>,
            lastActionLabel:
                null == lastActionLabel
                    ? _value.lastActionLabel
                    : lastActionLabel // ignore: cast_nullable_to_non_nullable
                        as String,
            lastAnnouncement:
                null == lastAnnouncement
                    ? _value.lastAnnouncement
                    : lastAnnouncement // ignore: cast_nullable_to_non_nullable
                        as String,
            matchWinner:
                freezed == matchWinner
                    ? _value.matchWinner
                    : matchWinner // ignore: cast_nullable_to_non_nullable
                        as Team?,
            matchWinnerName:
                null == matchWinnerName
                    ? _value.matchWinnerName
                    : matchWinnerName // ignore: cast_nullable_to_non_nullable
                        as String,
            matchCompleted:
                null == matchCompleted
                    ? _value.matchCompleted
                    : matchCompleted // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MatchScoreCopyWith<$Res> get match {
    return $MatchScoreCopyWith<$Res>(_value.match, (value) {
      return _then(_value.copyWith(match: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ScoringStateImplCopyWith<$Res>
    implements $ScoringStateCopyWith<$Res> {
  factory _$$ScoringStateImplCopyWith(
    _$ScoringStateImpl value,
    $Res Function(_$ScoringStateImpl) then,
  ) = __$$ScoringStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    MatchScore match,
    List<MatchScore> undoStack,
    List<MatchScore> redoStack,
    String lastActionLabel,
    String lastAnnouncement,
    Team? matchWinner,
    String matchWinnerName,
    bool matchCompleted,
  });

  @override
  $MatchScoreCopyWith<$Res> get match;
}

/// @nodoc
class __$$ScoringStateImplCopyWithImpl<$Res>
    extends _$ScoringStateCopyWithImpl<$Res, _$ScoringStateImpl>
    implements _$$ScoringStateImplCopyWith<$Res> {
  __$$ScoringStateImplCopyWithImpl(
    _$ScoringStateImpl _value,
    $Res Function(_$ScoringStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? match = null,
    Object? undoStack = null,
    Object? redoStack = null,
    Object? lastActionLabel = null,
    Object? lastAnnouncement = null,
    Object? matchWinner = freezed,
    Object? matchWinnerName = null,
    Object? matchCompleted = null,
  }) {
    return _then(
      _$ScoringStateImpl(
        match:
            null == match
                ? _value.match
                : match // ignore: cast_nullable_to_non_nullable
                    as MatchScore,
        undoStack:
            null == undoStack
                ? _value._undoStack
                : undoStack // ignore: cast_nullable_to_non_nullable
                    as List<MatchScore>,
        redoStack:
            null == redoStack
                ? _value._redoStack
                : redoStack // ignore: cast_nullable_to_non_nullable
                    as List<MatchScore>,
        lastActionLabel:
            null == lastActionLabel
                ? _value.lastActionLabel
                : lastActionLabel // ignore: cast_nullable_to_non_nullable
                    as String,
        lastAnnouncement:
            null == lastAnnouncement
                ? _value.lastAnnouncement
                : lastAnnouncement // ignore: cast_nullable_to_non_nullable
                    as String,
        matchWinner:
            freezed == matchWinner
                ? _value.matchWinner
                : matchWinner // ignore: cast_nullable_to_non_nullable
                    as Team?,
        matchWinnerName:
            null == matchWinnerName
                ? _value.matchWinnerName
                : matchWinnerName // ignore: cast_nullable_to_non_nullable
                    as String,
        matchCompleted:
            null == matchCompleted
                ? _value.matchCompleted
                : matchCompleted // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$ScoringStateImpl implements _ScoringState {
  const _$ScoringStateImpl({
    required this.match,
    final List<MatchScore> undoStack = const <MatchScore>[],
    final List<MatchScore> redoStack = const <MatchScore>[],
    this.lastActionLabel = '',
    this.lastAnnouncement = '',
    this.matchWinner,
    this.matchWinnerName = '',
    this.matchCompleted = false,
  }) : _undoStack = undoStack,
       _redoStack = redoStack;

  @override
  final MatchScore match;
  final List<MatchScore> _undoStack;
  @override
  @JsonKey()
  List<MatchScore> get undoStack {
    if (_undoStack is EqualUnmodifiableListView) return _undoStack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_undoStack);
  }

  final List<MatchScore> _redoStack;
  @override
  @JsonKey()
  List<MatchScore> get redoStack {
    if (_redoStack is EqualUnmodifiableListView) return _redoStack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_redoStack);
  }

  @override
  @JsonKey()
  final String lastActionLabel;
  @override
  @JsonKey()
  final String lastAnnouncement;
  // Campos para mostrar el ganador del partido
  @override
  final Team? matchWinner;
  @override
  @JsonKey()
  final String matchWinnerName;
  @override
  @JsonKey()
  final bool matchCompleted;

  @override
  String toString() {
    return 'ScoringState(match: $match, undoStack: $undoStack, redoStack: $redoStack, lastActionLabel: $lastActionLabel, lastAnnouncement: $lastAnnouncement, matchWinner: $matchWinner, matchWinnerName: $matchWinnerName, matchCompleted: $matchCompleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScoringStateImpl &&
            (identical(other.match, match) || other.match == match) &&
            const DeepCollectionEquality().equals(
              other._undoStack,
              _undoStack,
            ) &&
            const DeepCollectionEquality().equals(
              other._redoStack,
              _redoStack,
            ) &&
            (identical(other.lastActionLabel, lastActionLabel) ||
                other.lastActionLabel == lastActionLabel) &&
            (identical(other.lastAnnouncement, lastAnnouncement) ||
                other.lastAnnouncement == lastAnnouncement) &&
            (identical(other.matchWinner, matchWinner) ||
                other.matchWinner == matchWinner) &&
            (identical(other.matchWinnerName, matchWinnerName) ||
                other.matchWinnerName == matchWinnerName) &&
            (identical(other.matchCompleted, matchCompleted) ||
                other.matchCompleted == matchCompleted));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    match,
    const DeepCollectionEquality().hash(_undoStack),
    const DeepCollectionEquality().hash(_redoStack),
    lastActionLabel,
    lastAnnouncement,
    matchWinner,
    matchWinnerName,
    matchCompleted,
  );

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScoringStateImplCopyWith<_$ScoringStateImpl> get copyWith =>
      __$$ScoringStateImplCopyWithImpl<_$ScoringStateImpl>(this, _$identity);
}

abstract class _ScoringState implements ScoringState {
  const factory _ScoringState({
    required final MatchScore match,
    final List<MatchScore> undoStack,
    final List<MatchScore> redoStack,
    final String lastActionLabel,
    final String lastAnnouncement,
    final Team? matchWinner,
    final String matchWinnerName,
    final bool matchCompleted,
  }) = _$ScoringStateImpl;

  @override
  MatchScore get match;
  @override
  List<MatchScore> get undoStack;
  @override
  List<MatchScore> get redoStack;
  @override
  String get lastActionLabel;
  @override
  String get lastAnnouncement; // Campos para mostrar el ganador del partido
  @override
  Team? get matchWinner;
  @override
  String get matchWinnerName;
  @override
  bool get matchCompleted;

  /// Create a copy of ScoringState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScoringStateImplCopyWith<_$ScoringStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
