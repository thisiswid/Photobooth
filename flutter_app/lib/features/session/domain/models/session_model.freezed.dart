// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PhotoModel _$PhotoModelFromJson(Map<String, dynamic> json) {
  return _PhotoModel.fromJson(json);
}

/// @nodoc
mixin _$PhotoModel {
  String get id => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  String get fileUrl => throw _privateConstructorUsedError;
  PhotoType get type => throw _privateConstructorUsedError;
  DateTime? get capturedAt => throw _privateConstructorUsedError;

  /// How many retakes have been used for this pose slot (max 2).
  int get retakeCount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PhotoModelCopyWith<PhotoModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoModelCopyWith<$Res> {
  factory $PhotoModelCopyWith(
          PhotoModel value, $Res Function(PhotoModel) then) =
      _$PhotoModelCopyWithImpl<$Res, PhotoModel>;
  @useResult
  $Res call(
      {String id,
      String sessionId,
      String fileUrl,
      PhotoType type,
      DateTime? capturedAt,
      int retakeCount});
}

/// @nodoc
class _$PhotoModelCopyWithImpl<$Res, $Val extends PhotoModel>
    implements $PhotoModelCopyWith<$Res> {
  _$PhotoModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? fileUrl = null,
    Object? type = null,
    Object? capturedAt = freezed,
    Object? retakeCount = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as PhotoType,
      capturedAt: freezed == capturedAt
          ? _value.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      retakeCount: null == retakeCount
          ? _value.retakeCount
          : retakeCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoModelImplCopyWith<$Res>
    implements $PhotoModelCopyWith<$Res> {
  factory _$$PhotoModelImplCopyWith(
          _$PhotoModelImpl value, $Res Function(_$PhotoModelImpl) then) =
      __$$PhotoModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String sessionId,
      String fileUrl,
      PhotoType type,
      DateTime? capturedAt,
      int retakeCount});
}

/// @nodoc
class __$$PhotoModelImplCopyWithImpl<$Res>
    extends _$PhotoModelCopyWithImpl<$Res, _$PhotoModelImpl>
    implements _$$PhotoModelImplCopyWith<$Res> {
  __$$PhotoModelImplCopyWithImpl(
      _$PhotoModelImpl _value, $Res Function(_$PhotoModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? fileUrl = null,
    Object? type = null,
    Object? capturedAt = freezed,
    Object? retakeCount = null,
  }) {
    return _then(_$PhotoModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as PhotoType,
      capturedAt: freezed == capturedAt
          ? _value.capturedAt
          : capturedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      retakeCount: null == retakeCount
          ? _value.retakeCount
          : retakeCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoModelImpl extends _PhotoModel {
  const _$PhotoModelImpl(
      {required this.id,
      required this.sessionId,
      required this.fileUrl,
      this.type = PhotoType.raw,
      this.capturedAt,
      this.retakeCount = 0})
      : super._();

  factory _$PhotoModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoModelImplFromJson(json);

  @override
  final String id;
  @override
  final String sessionId;
  @override
  final String fileUrl;
  @override
  @JsonKey()
  final PhotoType type;
  @override
  final DateTime? capturedAt;

  /// How many retakes have been used for this pose slot (max 2).
  @override
  @JsonKey()
  final int retakeCount;

  @override
  String toString() {
    return 'PhotoModel(id: $id, sessionId: $sessionId, fileUrl: $fileUrl, type: $type, capturedAt: $capturedAt, retakeCount: $retakeCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.retakeCount, retakeCount) ||
                other.retakeCount == retakeCount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, sessionId, fileUrl, type, capturedAt, retakeCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoModelImplCopyWith<_$PhotoModelImpl> get copyWith =>
      __$$PhotoModelImplCopyWithImpl<_$PhotoModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoModelImplToJson(
      this,
    );
  }
}

abstract class _PhotoModel extends PhotoModel {
  const factory _PhotoModel(
      {required final String id,
      required final String sessionId,
      required final String fileUrl,
      final PhotoType type,
      final DateTime? capturedAt,
      final int retakeCount}) = _$PhotoModelImpl;
  const _PhotoModel._() : super._();

  factory _PhotoModel.fromJson(Map<String, dynamic> json) =
      _$PhotoModelImpl.fromJson;

  @override
  String get id;
  @override
  String get sessionId;
  @override
  String get fileUrl;
  @override
  PhotoType get type;
  @override
  DateTime? get capturedAt;
  @override

  /// How many retakes have been used for this pose slot (max 2).
  int get retakeCount;
  @override
  @JsonKey(ignore: true)
  _$$PhotoModelImplCopyWith<_$PhotoModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionModel _$SessionModelFromJson(Map<String, dynamic> json) {
  return _SessionModel.fromJson(json);
}

/// @nodoc
mixin _$SessionModel {
  /// Backend session ID.
  int get sessionId => throw _privateConstructorUsedError;

  /// Event this session belongs to.
  int get eventId => throw _privateConstructorUsedError;

  /// Session status — mirrors backend enum.
  String get status => throw _privateConstructorUsedError;

  /// Frame selected during Frame Selection (must be set before Photo Session).
  int? get frameId => throw _privateConstructorUsedError;

  /// Number of poses required by the selected frame.
  int get poseCount => throw _privateConstructorUsedError;

  /// Filter selected after all poses are captured.
  int? get filterId => throw _privateConstructorUsedError;
  String? get selectedFilter => throw _privateConstructorUsedError;

  /// Cumulative retake count across all poses.
  int get retakeCount => throw _privateConstructorUsedError;

  /// When the session started (timer origin).
  DateTime? get startedAt => throw _privateConstructorUsedError;

  /// Session deadline: startedAt + 5 minutes.
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  DateTime? get finishedAt => throw _privateConstructorUsedError;

  /// Captured photos for all poses.
  List<PhotoModel> get photos => throw _privateConstructorUsedError;

  /// Index of the current pose being shot (0-based).
  int get currentPoseIndex =>
      throw _privateConstructorUsedError; // ── Result fields (populated after processing) ──────────────────────────
  String? get finalUrl => throw _privateConstructorUsedError;
  String? get gifUrl => throw _privateConstructorUsedError;
  String? get qrToken => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SessionModelCopyWith<SessionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionModelCopyWith<$Res> {
  factory $SessionModelCopyWith(
          SessionModel value, $Res Function(SessionModel) then) =
      _$SessionModelCopyWithImpl<$Res, SessionModel>;
  @useResult
  $Res call(
      {int sessionId,
      int eventId,
      String status,
      int? frameId,
      int poseCount,
      int? filterId,
      String? selectedFilter,
      int retakeCount,
      DateTime? startedAt,
      DateTime? expiresAt,
      DateTime? finishedAt,
      List<PhotoModel> photos,
      int currentPoseIndex,
      String? finalUrl,
      String? gifUrl,
      String? qrToken});
}

/// @nodoc
class _$SessionModelCopyWithImpl<$Res, $Val extends SessionModel>
    implements $SessionModelCopyWith<$Res> {
  _$SessionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? eventId = null,
    Object? status = null,
    Object? frameId = freezed,
    Object? poseCount = null,
    Object? filterId = freezed,
    Object? selectedFilter = freezed,
    Object? retakeCount = null,
    Object? startedAt = freezed,
    Object? expiresAt = freezed,
    Object? finishedAt = freezed,
    Object? photos = null,
    Object? currentPoseIndex = null,
    Object? finalUrl = freezed,
    Object? gifUrl = freezed,
    Object? qrToken = freezed,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      frameId: freezed == frameId
          ? _value.frameId
          : frameId // ignore: cast_nullable_to_non_nullable
              as int?,
      poseCount: null == poseCount
          ? _value.poseCount
          : poseCount // ignore: cast_nullable_to_non_nullable
              as int,
      filterId: freezed == filterId
          ? _value.filterId
          : filterId // ignore: cast_nullable_to_non_nullable
              as int?,
      selectedFilter: freezed == selectedFilter
          ? _value.selectedFilter
          : selectedFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      retakeCount: null == retakeCount
          ? _value.retakeCount
          : retakeCount // ignore: cast_nullable_to_non_nullable
              as int,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      finishedAt: freezed == finishedAt
          ? _value.finishedAt
          : finishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photos: null == photos
          ? _value.photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<PhotoModel>,
      currentPoseIndex: null == currentPoseIndex
          ? _value.currentPoseIndex
          : currentPoseIndex // ignore: cast_nullable_to_non_nullable
              as int,
      finalUrl: freezed == finalUrl
          ? _value.finalUrl
          : finalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      gifUrl: freezed == gifUrl
          ? _value.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      qrToken: freezed == qrToken
          ? _value.qrToken
          : qrToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionModelImplCopyWith<$Res>
    implements $SessionModelCopyWith<$Res> {
  factory _$$SessionModelImplCopyWith(
          _$SessionModelImpl value, $Res Function(_$SessionModelImpl) then) =
      __$$SessionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int sessionId,
      int eventId,
      String status,
      int? frameId,
      int poseCount,
      int? filterId,
      String? selectedFilter,
      int retakeCount,
      DateTime? startedAt,
      DateTime? expiresAt,
      DateTime? finishedAt,
      List<PhotoModel> photos,
      int currentPoseIndex,
      String? finalUrl,
      String? gifUrl,
      String? qrToken});
}

/// @nodoc
class __$$SessionModelImplCopyWithImpl<$Res>
    extends _$SessionModelCopyWithImpl<$Res, _$SessionModelImpl>
    implements _$$SessionModelImplCopyWith<$Res> {
  __$$SessionModelImplCopyWithImpl(
      _$SessionModelImpl _value, $Res Function(_$SessionModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? eventId = null,
    Object? status = null,
    Object? frameId = freezed,
    Object? poseCount = null,
    Object? filterId = freezed,
    Object? selectedFilter = freezed,
    Object? retakeCount = null,
    Object? startedAt = freezed,
    Object? expiresAt = freezed,
    Object? finishedAt = freezed,
    Object? photos = null,
    Object? currentPoseIndex = null,
    Object? finalUrl = freezed,
    Object? gifUrl = freezed,
    Object? qrToken = freezed,
  }) {
    return _then(_$SessionModelImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as int,
      eventId: null == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      frameId: freezed == frameId
          ? _value.frameId
          : frameId // ignore: cast_nullable_to_non_nullable
              as int?,
      poseCount: null == poseCount
          ? _value.poseCount
          : poseCount // ignore: cast_nullable_to_non_nullable
              as int,
      filterId: freezed == filterId
          ? _value.filterId
          : filterId // ignore: cast_nullable_to_non_nullable
              as int?,
      selectedFilter: freezed == selectedFilter
          ? _value.selectedFilter
          : selectedFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      retakeCount: null == retakeCount
          ? _value.retakeCount
          : retakeCount // ignore: cast_nullable_to_non_nullable
              as int,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      finishedAt: freezed == finishedAt
          ? _value.finishedAt
          : finishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photos: null == photos
          ? _value._photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<PhotoModel>,
      currentPoseIndex: null == currentPoseIndex
          ? _value.currentPoseIndex
          : currentPoseIndex // ignore: cast_nullable_to_non_nullable
              as int,
      finalUrl: freezed == finalUrl
          ? _value.finalUrl
          : finalUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      gifUrl: freezed == gifUrl
          ? _value.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      qrToken: freezed == qrToken
          ? _value.qrToken
          : qrToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionModelImpl extends _SessionModel {
  const _$SessionModelImpl(
      {required this.sessionId,
      required this.eventId,
      this.status = 'active',
      this.frameId,
      this.poseCount = 1,
      this.filterId,
      this.selectedFilter,
      this.retakeCount = 0,
      this.startedAt,
      this.expiresAt,
      this.finishedAt,
      final List<PhotoModel> photos = const [],
      this.currentPoseIndex = 0,
      this.finalUrl,
      this.gifUrl,
      this.qrToken})
      : _photos = photos,
        super._();

  factory _$SessionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionModelImplFromJson(json);

  /// Backend session ID.
  @override
  final int sessionId;

  /// Event this session belongs to.
  @override
  final int eventId;

  /// Session status — mirrors backend enum.
  @override
  @JsonKey()
  final String status;

  /// Frame selected during Frame Selection (must be set before Photo Session).
  @override
  final int? frameId;

  /// Number of poses required by the selected frame.
  @override
  @JsonKey()
  final int poseCount;

  /// Filter selected after all poses are captured.
  @override
  final int? filterId;
  @override
  final String? selectedFilter;

  /// Cumulative retake count across all poses.
  @override
  @JsonKey()
  final int retakeCount;

  /// When the session started (timer origin).
  @override
  final DateTime? startedAt;

  /// Session deadline: startedAt + 5 minutes.
  @override
  final DateTime? expiresAt;
  @override
  final DateTime? finishedAt;

  /// Captured photos for all poses.
  final List<PhotoModel> _photos;

  /// Captured photos for all poses.
  @override
  @JsonKey()
  List<PhotoModel> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  /// Index of the current pose being shot (0-based).
  @override
  @JsonKey()
  final int currentPoseIndex;
// ── Result fields (populated after processing) ──────────────────────────
  @override
  final String? finalUrl;
  @override
  final String? gifUrl;
  @override
  final String? qrToken;

  @override
  String toString() {
    return 'SessionModel(sessionId: $sessionId, eventId: $eventId, status: $status, frameId: $frameId, poseCount: $poseCount, filterId: $filterId, selectedFilter: $selectedFilter, retakeCount: $retakeCount, startedAt: $startedAt, expiresAt: $expiresAt, finishedAt: $finishedAt, photos: $photos, currentPoseIndex: $currentPoseIndex, finalUrl: $finalUrl, gifUrl: $gifUrl, qrToken: $qrToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionModelImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.frameId, frameId) || other.frameId == frameId) &&
            (identical(other.poseCount, poseCount) ||
                other.poseCount == poseCount) &&
            (identical(other.filterId, filterId) ||
                other.filterId == filterId) &&
            (identical(other.selectedFilter, selectedFilter) ||
                other.selectedFilter == selectedFilter) &&
            (identical(other.retakeCount, retakeCount) ||
                other.retakeCount == retakeCount) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.finishedAt, finishedAt) ||
                other.finishedAt == finishedAt) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            (identical(other.currentPoseIndex, currentPoseIndex) ||
                other.currentPoseIndex == currentPoseIndex) &&
            (identical(other.finalUrl, finalUrl) ||
                other.finalUrl == finalUrl) &&
            (identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl) &&
            (identical(other.qrToken, qrToken) || other.qrToken == qrToken));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionId,
      eventId,
      status,
      frameId,
      poseCount,
      filterId,
      selectedFilter,
      retakeCount,
      startedAt,
      expiresAt,
      finishedAt,
      const DeepCollectionEquality().hash(_photos),
      currentPoseIndex,
      finalUrl,
      gifUrl,
      qrToken);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionModelImplCopyWith<_$SessionModelImpl> get copyWith =>
      __$$SessionModelImplCopyWithImpl<_$SessionModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionModelImplToJson(
      this,
    );
  }
}

abstract class _SessionModel extends SessionModel {
  const factory _SessionModel(
      {required final int sessionId,
      required final int eventId,
      final String status,
      final int? frameId,
      final int poseCount,
      final int? filterId,
      final String? selectedFilter,
      final int retakeCount,
      final DateTime? startedAt,
      final DateTime? expiresAt,
      final DateTime? finishedAt,
      final List<PhotoModel> photos,
      final int currentPoseIndex,
      final String? finalUrl,
      final String? gifUrl,
      final String? qrToken}) = _$SessionModelImpl;
  const _SessionModel._() : super._();

  factory _SessionModel.fromJson(Map<String, dynamic> json) =
      _$SessionModelImpl.fromJson;

  @override

  /// Backend session ID.
  int get sessionId;
  @override

  /// Event this session belongs to.
  int get eventId;
  @override

  /// Session status — mirrors backend enum.
  String get status;
  @override

  /// Frame selected during Frame Selection (must be set before Photo Session).
  int? get frameId;
  @override

  /// Number of poses required by the selected frame.
  int get poseCount;
  @override

  /// Filter selected after all poses are captured.
  int? get filterId;
  @override
  String? get selectedFilter;
  @override

  /// Cumulative retake count across all poses.
  int get retakeCount;
  @override

  /// When the session started (timer origin).
  DateTime? get startedAt;
  @override

  /// Session deadline: startedAt + 5 minutes.
  DateTime? get expiresAt;
  @override
  DateTime? get finishedAt;
  @override

  /// Captured photos for all poses.
  List<PhotoModel> get photos;
  @override

  /// Index of the current pose being shot (0-based).
  int get currentPoseIndex;
  @override // ── Result fields (populated after processing) ──────────────────────────
  String? get finalUrl;
  @override
  String? get gifUrl;
  @override
  String? get qrToken;
  @override
  @JsonKey(ignore: true)
  _$$SessionModelImplCopyWith<_$SessionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
