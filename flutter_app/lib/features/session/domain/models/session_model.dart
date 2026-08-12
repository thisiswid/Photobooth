import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_model.freezed.dart';
part 'session_model.g.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Payment status — mirrors backend SESSIONS.status for the payment phase.
enum PaymentStatus {
  @JsonValue('pending') pending,
  @JsonValue('paid')    paid,
  @JsonValue('failed')  failed,
}

/// Photo type — mirrors PHOTOS.type in the ERD.
enum PhotoType {
  @JsonValue('raw')   raw,
  @JsonValue('final') final_,
}

// ── PhotoModel ────────────────────────────────────────────────────────────────

/// A single captured photo for one pose slot.
/// [retakeCount] tracks how many times this pose has been retaken (max 2).
@freezed
class PhotoModel with _$PhotoModel {
  const factory PhotoModel({
    required String id,
    required String sessionId,
    required String fileUrl,
    @Default(PhotoType.raw) PhotoType type,
    DateTime? capturedAt,
    /// How many retakes have been used for this pose slot (max 2).
    @Default(0) int retakeCount,
  }) = _PhotoModel;

  factory PhotoModel.fromJson(Map<String, dynamic> json) =>
      _$PhotoModelFromJson(json);

  const PhotoModel._();

  /// Whether this pose can still be retaken (business rule: max 2 per pose).
  bool get canRetake => retakeCount < 2;
}

// ── SessionModel ──────────────────────────────────────────────────────────────

/// Represents an active photobooth session, aligned to the ERD SESSIONS table.
///
/// Timer: [expiresAt] = [startedAt] + 5 minutes (set at Start Session).
/// Timer is NOT active during Welcome, Tutorial, or Payment screens.
@freezed
class SessionModel with _$SessionModel {
  const factory SessionModel({
    /// Backend session ID.
    required int    sessionId,
    /// Event this session belongs to.
    required int    eventId,
    /// Session status — mirrors backend enum.
    @Default('active') String status,
    /// Frame selected during Frame Selection (must be set before Photo Session).
    int?    frameId,
    /// Number of poses required by the selected frame.
    @Default(1) int poseCount,
    /// Filter selected after all poses are captured.
    int?    filterId,
    String? selectedFilter,
    /// Cumulative retake count across all poses.
    @Default(0) int retakeCount,
    /// When the session started (timer origin).
    DateTime? startedAt,
    /// Session deadline: startedAt + 5 minutes.
    DateTime? expiresAt,
    DateTime? finishedAt,
    /// Captured photos for all poses.
    @Default([]) List<PhotoModel> photos,
    /// Index of the current pose being shot (0-based).
    @Default(0) int currentPoseIndex,
    // ── Result fields (populated after processing) ──────────────────────────
    String? finalUrl,
    String? gifUrl,
    String? qrToken,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  const SessionModel._();

  // ── Computed ───────────────────────────────────────────────────────────────

  bool get isPaid      => status == 'active' || status == 'processing' ||
                          status == 'result_ready' || status == 'finished';

  bool get isExpired   => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get allPosesDone => photos.length >= poseCount;

  /// Remaining session time. Returns [Duration.zero] when expired.
  Duration get remainingTime {
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// How many retakes have been used for a given pose [index].
  int retakeCountFor(int poseIndex) =>
      poseIndex < photos.length ? photos[poseIndex].retakeCount : 0;

  /// Whether the pose at [index] can still be retaken (max 2 per pose).
  bool canRetakePose(int poseIndex) => retakeCountFor(poseIndex) < 2;
}
