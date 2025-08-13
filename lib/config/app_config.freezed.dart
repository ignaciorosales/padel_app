// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TeamDef _$TeamDefFromJson(Map<String, dynamic> json) {
  return _TeamDef.fromJson(json);
}

/// @nodoc
mixin _$TeamDef {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  List<String> get synonyms => throw _privateConstructorUsedError;
  String get colorHex => throw _privateConstructorUsedError;

  /// Serializes this TeamDef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamDef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamDefCopyWith<TeamDef> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamDefCopyWith<$Res> {
  factory $TeamDefCopyWith(TeamDef value, $Res Function(TeamDef) then) =
      _$TeamDefCopyWithImpl<$Res, TeamDef>;
  @useResult
  $Res call({
    String id,
    String displayName,
    List<String> synonyms,
    String colorHex,
  });
}

/// @nodoc
class _$TeamDefCopyWithImpl<$Res, $Val extends TeamDef>
    implements $TeamDefCopyWith<$Res> {
  _$TeamDefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamDef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? synonyms = null,
    Object? colorHex = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            displayName:
                null == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String,
            synonyms:
                null == synonyms
                    ? _value.synonyms
                    : synonyms // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            colorHex:
                null == colorHex
                    ? _value.colorHex
                    : colorHex // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamDefImplCopyWith<$Res> implements $TeamDefCopyWith<$Res> {
  factory _$$TeamDefImplCopyWith(
    _$TeamDefImpl value,
    $Res Function(_$TeamDefImpl) then,
  ) = __$$TeamDefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    List<String> synonyms,
    String colorHex,
  });
}

/// @nodoc
class __$$TeamDefImplCopyWithImpl<$Res>
    extends _$TeamDefCopyWithImpl<$Res, _$TeamDefImpl>
    implements _$$TeamDefImplCopyWith<$Res> {
  __$$TeamDefImplCopyWithImpl(
    _$TeamDefImpl _value,
    $Res Function(_$TeamDefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamDef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? synonyms = null,
    Object? colorHex = null,
  }) {
    return _then(
      _$TeamDefImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        displayName:
            null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String,
        synonyms:
            null == synonyms
                ? _value._synonyms
                : synonyms // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        colorHex:
            null == colorHex
                ? _value.colorHex
                : colorHex // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamDefImpl implements _TeamDef {
  const _$TeamDefImpl({
    required this.id,
    required this.displayName,
    final List<String> synonyms = const [],
    this.colorHex = '#1E88E5',
  }) : _synonyms = synonyms;

  factory _$TeamDefImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamDefImplFromJson(json);

  @override
  final String id;
  @override
  final String displayName;
  final List<String> _synonyms;
  @override
  @JsonKey()
  List<String> get synonyms {
    if (_synonyms is EqualUnmodifiableListView) return _synonyms;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_synonyms);
  }

  @override
  @JsonKey()
  final String colorHex;

  @override
  String toString() {
    return 'TeamDef(id: $id, displayName: $displayName, synonyms: $synonyms, colorHex: $colorHex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamDefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            const DeepCollectionEquality().equals(other._synonyms, _synonyms) &&
            (identical(other.colorHex, colorHex) ||
                other.colorHex == colorHex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    const DeepCollectionEquality().hash(_synonyms),
    colorHex,
  );

  /// Create a copy of TeamDef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamDefImplCopyWith<_$TeamDefImpl> get copyWith =>
      __$$TeamDefImplCopyWithImpl<_$TeamDefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamDefImplToJson(this);
  }
}

abstract class _TeamDef implements TeamDef {
  const factory _TeamDef({
    required final String id,
    required final String displayName,
    final List<String> synonyms,
    final String colorHex,
  }) = _$TeamDefImpl;

  factory _TeamDef.fromJson(Map<String, dynamic> json) = _$TeamDefImpl.fromJson;

  @override
  String get id;
  @override
  String get displayName;
  @override
  List<String> get synonyms;
  @override
  String get colorHex;

  /// Create a copy of TeamDef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamDefImplCopyWith<_$TeamDefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RulesConfig _$RulesConfigFromJson(Map<String, dynamic> json) {
  return _RulesConfig.fromJson(json);
}

/// @nodoc
mixin _$RulesConfig {
  int get setsToWin => throw _privateConstructorUsedError;
  bool get tiebreakAtSixSix => throw _privateConstructorUsedError;
  int get tiebreakTarget => throw _privateConstructorUsedError;
  bool get goldenPoint => throw _privateConstructorUsedError;
  String get startingServerId => throw _privateConstructorUsedError;

  /// Serializes this RulesConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RulesConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RulesConfigCopyWith<RulesConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RulesConfigCopyWith<$Res> {
  factory $RulesConfigCopyWith(
    RulesConfig value,
    $Res Function(RulesConfig) then,
  ) = _$RulesConfigCopyWithImpl<$Res, RulesConfig>;
  @useResult
  $Res call({
    int setsToWin,
    bool tiebreakAtSixSix,
    int tiebreakTarget,
    bool goldenPoint,
    String startingServerId,
  });
}

/// @nodoc
class _$RulesConfigCopyWithImpl<$Res, $Val extends RulesConfig>
    implements $RulesConfigCopyWith<$Res> {
  _$RulesConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RulesConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setsToWin = null,
    Object? tiebreakAtSixSix = null,
    Object? tiebreakTarget = null,
    Object? goldenPoint = null,
    Object? startingServerId = null,
  }) {
    return _then(
      _value.copyWith(
            setsToWin:
                null == setsToWin
                    ? _value.setsToWin
                    : setsToWin // ignore: cast_nullable_to_non_nullable
                        as int,
            tiebreakAtSixSix:
                null == tiebreakAtSixSix
                    ? _value.tiebreakAtSixSix
                    : tiebreakAtSixSix // ignore: cast_nullable_to_non_nullable
                        as bool,
            tiebreakTarget:
                null == tiebreakTarget
                    ? _value.tiebreakTarget
                    : tiebreakTarget // ignore: cast_nullable_to_non_nullable
                        as int,
            goldenPoint:
                null == goldenPoint
                    ? _value.goldenPoint
                    : goldenPoint // ignore: cast_nullable_to_non_nullable
                        as bool,
            startingServerId:
                null == startingServerId
                    ? _value.startingServerId
                    : startingServerId // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RulesConfigImplCopyWith<$Res>
    implements $RulesConfigCopyWith<$Res> {
  factory _$$RulesConfigImplCopyWith(
    _$RulesConfigImpl value,
    $Res Function(_$RulesConfigImpl) then,
  ) = __$$RulesConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int setsToWin,
    bool tiebreakAtSixSix,
    int tiebreakTarget,
    bool goldenPoint,
    String startingServerId,
  });
}

/// @nodoc
class __$$RulesConfigImplCopyWithImpl<$Res>
    extends _$RulesConfigCopyWithImpl<$Res, _$RulesConfigImpl>
    implements _$$RulesConfigImplCopyWith<$Res> {
  __$$RulesConfigImplCopyWithImpl(
    _$RulesConfigImpl _value,
    $Res Function(_$RulesConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RulesConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setsToWin = null,
    Object? tiebreakAtSixSix = null,
    Object? tiebreakTarget = null,
    Object? goldenPoint = null,
    Object? startingServerId = null,
  }) {
    return _then(
      _$RulesConfigImpl(
        setsToWin:
            null == setsToWin
                ? _value.setsToWin
                : setsToWin // ignore: cast_nullable_to_non_nullable
                    as int,
        tiebreakAtSixSix:
            null == tiebreakAtSixSix
                ? _value.tiebreakAtSixSix
                : tiebreakAtSixSix // ignore: cast_nullable_to_non_nullable
                    as bool,
        tiebreakTarget:
            null == tiebreakTarget
                ? _value.tiebreakTarget
                : tiebreakTarget // ignore: cast_nullable_to_non_nullable
                    as int,
        goldenPoint:
            null == goldenPoint
                ? _value.goldenPoint
                : goldenPoint // ignore: cast_nullable_to_non_nullable
                    as bool,
        startingServerId:
            null == startingServerId
                ? _value.startingServerId
                : startingServerId // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RulesConfigImpl implements _RulesConfig {
  const _$RulesConfigImpl({
    this.setsToWin = 2,
    this.tiebreakAtSixSix = true,
    this.tiebreakTarget = 7,
    this.goldenPoint = true,
    this.startingServerId = 'team1',
  });

  factory _$RulesConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$RulesConfigImplFromJson(json);

  @override
  @JsonKey()
  final int setsToWin;
  @override
  @JsonKey()
  final bool tiebreakAtSixSix;
  @override
  @JsonKey()
  final int tiebreakTarget;
  @override
  @JsonKey()
  final bool goldenPoint;
  @override
  @JsonKey()
  final String startingServerId;

  @override
  String toString() {
    return 'RulesConfig(setsToWin: $setsToWin, tiebreakAtSixSix: $tiebreakAtSixSix, tiebreakTarget: $tiebreakTarget, goldenPoint: $goldenPoint, startingServerId: $startingServerId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RulesConfigImpl &&
            (identical(other.setsToWin, setsToWin) ||
                other.setsToWin == setsToWin) &&
            (identical(other.tiebreakAtSixSix, tiebreakAtSixSix) ||
                other.tiebreakAtSixSix == tiebreakAtSixSix) &&
            (identical(other.tiebreakTarget, tiebreakTarget) ||
                other.tiebreakTarget == tiebreakTarget) &&
            (identical(other.goldenPoint, goldenPoint) ||
                other.goldenPoint == goldenPoint) &&
            (identical(other.startingServerId, startingServerId) ||
                other.startingServerId == startingServerId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    setsToWin,
    tiebreakAtSixSix,
    tiebreakTarget,
    goldenPoint,
    startingServerId,
  );

  /// Create a copy of RulesConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RulesConfigImplCopyWith<_$RulesConfigImpl> get copyWith =>
      __$$RulesConfigImplCopyWithImpl<_$RulesConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RulesConfigImplToJson(this);
  }
}

abstract class _RulesConfig implements RulesConfig {
  const factory _RulesConfig({
    final int setsToWin,
    final bool tiebreakAtSixSix,
    final int tiebreakTarget,
    final bool goldenPoint,
    final String startingServerId,
  }) = _$RulesConfigImpl;

  factory _RulesConfig.fromJson(Map<String, dynamic> json) =
      _$RulesConfigImpl.fromJson;

  @override
  int get setsToWin;
  @override
  bool get tiebreakAtSixSix;
  @override
  int get tiebreakTarget;
  @override
  bool get goldenPoint;
  @override
  String get startingServerId;

  /// Create a copy of RulesConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RulesConfigImplCopyWith<_$RulesConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UiConfig _$UiConfigFromJson(Map<String, dynamic> json) {
  return _UiConfig.fromJson(json);
}

/// @nodoc
mixin _$UiConfig {
  String get seedColorHex => throw _privateConstructorUsedError;
  bool get showGoldenPointChip => throw _privateConstructorUsedError;

  /// Serializes this UiConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UiConfigCopyWith<UiConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UiConfigCopyWith<$Res> {
  factory $UiConfigCopyWith(UiConfig value, $Res Function(UiConfig) then) =
      _$UiConfigCopyWithImpl<$Res, UiConfig>;
  @useResult
  $Res call({String seedColorHex, bool showGoldenPointChip});
}

/// @nodoc
class _$UiConfigCopyWithImpl<$Res, $Val extends UiConfig>
    implements $UiConfigCopyWith<$Res> {
  _$UiConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? seedColorHex = null, Object? showGoldenPointChip = null}) {
    return _then(
      _value.copyWith(
            seedColorHex:
                null == seedColorHex
                    ? _value.seedColorHex
                    : seedColorHex // ignore: cast_nullable_to_non_nullable
                        as String,
            showGoldenPointChip:
                null == showGoldenPointChip
                    ? _value.showGoldenPointChip
                    : showGoldenPointChip // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UiConfigImplCopyWith<$Res>
    implements $UiConfigCopyWith<$Res> {
  factory _$$UiConfigImplCopyWith(
    _$UiConfigImpl value,
    $Res Function(_$UiConfigImpl) then,
  ) = __$$UiConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String seedColorHex, bool showGoldenPointChip});
}

/// @nodoc
class __$$UiConfigImplCopyWithImpl<$Res>
    extends _$UiConfigCopyWithImpl<$Res, _$UiConfigImpl>
    implements _$$UiConfigImplCopyWith<$Res> {
  __$$UiConfigImplCopyWithImpl(
    _$UiConfigImpl _value,
    $Res Function(_$UiConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? seedColorHex = null, Object? showGoldenPointChip = null}) {
    return _then(
      _$UiConfigImpl(
        seedColorHex:
            null == seedColorHex
                ? _value.seedColorHex
                : seedColorHex // ignore: cast_nullable_to_non_nullable
                    as String,
        showGoldenPointChip:
            null == showGoldenPointChip
                ? _value.showGoldenPointChip
                : showGoldenPointChip // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UiConfigImpl implements _UiConfig {
  const _$UiConfigImpl({
    this.seedColorHex = '#0062FF',
    this.showGoldenPointChip = true,
  });

  factory _$UiConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$UiConfigImplFromJson(json);

  @override
  @JsonKey()
  final String seedColorHex;
  @override
  @JsonKey()
  final bool showGoldenPointChip;

  @override
  String toString() {
    return 'UiConfig(seedColorHex: $seedColorHex, showGoldenPointChip: $showGoldenPointChip)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UiConfigImpl &&
            (identical(other.seedColorHex, seedColorHex) ||
                other.seedColorHex == seedColorHex) &&
            (identical(other.showGoldenPointChip, showGoldenPointChip) ||
                other.showGoldenPointChip == showGoldenPointChip));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, seedColorHex, showGoldenPointChip);

  /// Create a copy of UiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UiConfigImplCopyWith<_$UiConfigImpl> get copyWith =>
      __$$UiConfigImplCopyWithImpl<_$UiConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UiConfigImplToJson(this);
  }
}

abstract class _UiConfig implements UiConfig {
  const factory _UiConfig({
    final String seedColorHex,
    final bool showGoldenPointChip,
  }) = _$UiConfigImpl;

  factory _UiConfig.fromJson(Map<String, dynamic> json) =
      _$UiConfigImpl.fromJson;

  @override
  String get seedColorHex;
  @override
  bool get showGoldenPointChip;

  /// Create a copy of UiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UiConfigImplCopyWith<_$UiConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VoiceConfig _$VoiceConfigFromJson(Map<String, dynamic> json) {
  return _VoiceConfig.fromJson(json);
}

/// @nodoc
mixin _$VoiceConfig {
  String get wakeWord => throw _privateConstructorUsedError;
  String get language => throw _privateConstructorUsedError;

  /// Serializes this VoiceConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VoiceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceConfigCopyWith<VoiceConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceConfigCopyWith<$Res> {
  factory $VoiceConfigCopyWith(
    VoiceConfig value,
    $Res Function(VoiceConfig) then,
  ) = _$VoiceConfigCopyWithImpl<$Res, VoiceConfig>;
  @useResult
  $Res call({String wakeWord, String language});
}

/// @nodoc
class _$VoiceConfigCopyWithImpl<$Res, $Val extends VoiceConfig>
    implements $VoiceConfigCopyWith<$Res> {
  _$VoiceConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VoiceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? wakeWord = null, Object? language = null}) {
    return _then(
      _value.copyWith(
            wakeWord:
                null == wakeWord
                    ? _value.wakeWord
                    : wakeWord // ignore: cast_nullable_to_non_nullable
                        as String,
            language:
                null == language
                    ? _value.language
                    : language // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VoiceConfigImplCopyWith<$Res>
    implements $VoiceConfigCopyWith<$Res> {
  factory _$$VoiceConfigImplCopyWith(
    _$VoiceConfigImpl value,
    $Res Function(_$VoiceConfigImpl) then,
  ) = __$$VoiceConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String wakeWord, String language});
}

/// @nodoc
class __$$VoiceConfigImplCopyWithImpl<$Res>
    extends _$VoiceConfigCopyWithImpl<$Res, _$VoiceConfigImpl>
    implements _$$VoiceConfigImplCopyWith<$Res> {
  __$$VoiceConfigImplCopyWithImpl(
    _$VoiceConfigImpl _value,
    $Res Function(_$VoiceConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VoiceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? wakeWord = null, Object? language = null}) {
    return _then(
      _$VoiceConfigImpl(
        wakeWord:
            null == wakeWord
                ? _value.wakeWord
                : wakeWord // ignore: cast_nullable_to_non_nullable
                    as String,
        language:
            null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VoiceConfigImpl implements _VoiceConfig {
  const _$VoiceConfigImpl({
    this.wakeWord = 'marcador',
    this.language = 'es-ES',
  });

  factory _$VoiceConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoiceConfigImplFromJson(json);

  @override
  @JsonKey()
  final String wakeWord;
  @override
  @JsonKey()
  final String language;

  @override
  String toString() {
    return 'VoiceConfig(wakeWord: $wakeWord, language: $language)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceConfigImpl &&
            (identical(other.wakeWord, wakeWord) ||
                other.wakeWord == wakeWord) &&
            (identical(other.language, language) ||
                other.language == language));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, wakeWord, language);

  /// Create a copy of VoiceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceConfigImplCopyWith<_$VoiceConfigImpl> get copyWith =>
      __$$VoiceConfigImplCopyWithImpl<_$VoiceConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoiceConfigImplToJson(this);
  }
}

abstract class _VoiceConfig implements VoiceConfig {
  const factory _VoiceConfig({final String wakeWord, final String language}) =
      _$VoiceConfigImpl;

  factory _VoiceConfig.fromJson(Map<String, dynamic> json) =
      _$VoiceConfigImpl.fromJson;

  @override
  String get wakeWord;
  @override
  String get language;

  /// Create a copy of VoiceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceConfigImplCopyWith<_$VoiceConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return _AppConfig.fromJson(json);
}

/// @nodoc
mixin _$AppConfig {
  UiConfig get ui => throw _privateConstructorUsedError;
  List<TeamDef> get teams =>
      throw _privateConstructorUsedError; // orden = team1, team2
  RulesConfig get rules => throw _privateConstructorUsedError;
  VoiceConfig get voice => throw _privateConstructorUsedError;

  /// Serializes this AppConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppConfigCopyWith<AppConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppConfigCopyWith<$Res> {
  factory $AppConfigCopyWith(AppConfig value, $Res Function(AppConfig) then) =
      _$AppConfigCopyWithImpl<$Res, AppConfig>;
  @useResult
  $Res call({
    UiConfig ui,
    List<TeamDef> teams,
    RulesConfig rules,
    VoiceConfig voice,
  });

  $UiConfigCopyWith<$Res> get ui;
  $RulesConfigCopyWith<$Res> get rules;
  $VoiceConfigCopyWith<$Res> get voice;
}

/// @nodoc
class _$AppConfigCopyWithImpl<$Res, $Val extends AppConfig>
    implements $AppConfigCopyWith<$Res> {
  _$AppConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ui = null,
    Object? teams = null,
    Object? rules = null,
    Object? voice = null,
  }) {
    return _then(
      _value.copyWith(
            ui:
                null == ui
                    ? _value.ui
                    : ui // ignore: cast_nullable_to_non_nullable
                        as UiConfig,
            teams:
                null == teams
                    ? _value.teams
                    : teams // ignore: cast_nullable_to_non_nullable
                        as List<TeamDef>,
            rules:
                null == rules
                    ? _value.rules
                    : rules // ignore: cast_nullable_to_non_nullable
                        as RulesConfig,
            voice:
                null == voice
                    ? _value.voice
                    : voice // ignore: cast_nullable_to_non_nullable
                        as VoiceConfig,
          )
          as $Val,
    );
  }

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UiConfigCopyWith<$Res> get ui {
    return $UiConfigCopyWith<$Res>(_value.ui, (value) {
      return _then(_value.copyWith(ui: value) as $Val);
    });
  }

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RulesConfigCopyWith<$Res> get rules {
    return $RulesConfigCopyWith<$Res>(_value.rules, (value) {
      return _then(_value.copyWith(rules: value) as $Val);
    });
  }

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VoiceConfigCopyWith<$Res> get voice {
    return $VoiceConfigCopyWith<$Res>(_value.voice, (value) {
      return _then(_value.copyWith(voice: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppConfigImplCopyWith<$Res>
    implements $AppConfigCopyWith<$Res> {
  factory _$$AppConfigImplCopyWith(
    _$AppConfigImpl value,
    $Res Function(_$AppConfigImpl) then,
  ) = __$$AppConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    UiConfig ui,
    List<TeamDef> teams,
    RulesConfig rules,
    VoiceConfig voice,
  });

  @override
  $UiConfigCopyWith<$Res> get ui;
  @override
  $RulesConfigCopyWith<$Res> get rules;
  @override
  $VoiceConfigCopyWith<$Res> get voice;
}

/// @nodoc
class __$$AppConfigImplCopyWithImpl<$Res>
    extends _$AppConfigCopyWithImpl<$Res, _$AppConfigImpl>
    implements _$$AppConfigImplCopyWith<$Res> {
  __$$AppConfigImplCopyWithImpl(
    _$AppConfigImpl _value,
    $Res Function(_$AppConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ui = null,
    Object? teams = null,
    Object? rules = null,
    Object? voice = null,
  }) {
    return _then(
      _$AppConfigImpl(
        ui:
            null == ui
                ? _value.ui
                : ui // ignore: cast_nullable_to_non_nullable
                    as UiConfig,
        teams:
            null == teams
                ? _value._teams
                : teams // ignore: cast_nullable_to_non_nullable
                    as List<TeamDef>,
        rules:
            null == rules
                ? _value.rules
                : rules // ignore: cast_nullable_to_non_nullable
                    as RulesConfig,
        voice:
            null == voice
                ? _value.voice
                : voice // ignore: cast_nullable_to_non_nullable
                    as VoiceConfig,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppConfigImpl implements _AppConfig {
  const _$AppConfigImpl({
    this.ui = const UiConfig(),
    final List<TeamDef> teams = const <TeamDef>[],
    this.rules = const RulesConfig(),
    this.voice = const VoiceConfig(),
  }) : _teams = teams;

  factory _$AppConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppConfigImplFromJson(json);

  @override
  @JsonKey()
  final UiConfig ui;
  final List<TeamDef> _teams;
  @override
  @JsonKey()
  List<TeamDef> get teams {
    if (_teams is EqualUnmodifiableListView) return _teams;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_teams);
  }

  // orden = team1, team2
  @override
  @JsonKey()
  final RulesConfig rules;
  @override
  @JsonKey()
  final VoiceConfig voice;

  @override
  String toString() {
    return 'AppConfig(ui: $ui, teams: $teams, rules: $rules, voice: $voice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppConfigImpl &&
            (identical(other.ui, ui) || other.ui == ui) &&
            const DeepCollectionEquality().equals(other._teams, _teams) &&
            (identical(other.rules, rules) || other.rules == rules) &&
            (identical(other.voice, voice) || other.voice == voice));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    ui,
    const DeepCollectionEquality().hash(_teams),
    rules,
    voice,
  );

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppConfigImplCopyWith<_$AppConfigImpl> get copyWith =>
      __$$AppConfigImplCopyWithImpl<_$AppConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppConfigImplToJson(this);
  }
}

abstract class _AppConfig implements AppConfig {
  const factory _AppConfig({
    final UiConfig ui,
    final List<TeamDef> teams,
    final RulesConfig rules,
    final VoiceConfig voice,
  }) = _$AppConfigImpl;

  factory _AppConfig.fromJson(Map<String, dynamic> json) =
      _$AppConfigImpl.fromJson;

  @override
  UiConfig get ui;
  @override
  List<TeamDef> get teams; // orden = team1, team2
  @override
  RulesConfig get rules;
  @override
  VoiceConfig get voice;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppConfigImplCopyWith<_$AppConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
