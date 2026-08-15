import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../filter/domain/models/filter_model.dart';
import '../../frame/domain/models/frame_model.dart';
import '../domain/models/session_model.dart';

part 'session_provider.g.dart';

// ── SessionState ──────────────────────────────────────────────────────────────

/// Full state of an active photobooth session.
class SessionState {
  const SessionState({
    this.session,
    this.selectedFrame,
    this.selectedFilter,
    this.currentPoseIndex = 0,
    this.isMirrorEnabled = false,
    this.isLoading = false,
    this.error,
  });

  final SessionModel? session;
  final FrameModel? selectedFrame;
  final FilterModel? selectedFilter;

  /// Which pose slot is currently being shot (0-based).
  final int currentPoseIndex;

  /// Mirror toggle state for the current photo session.
  final bool isMirrorEnabled;

  final bool isLoading;
  final String? error;

  // ── Computed ─────────────────────────────────────────────────────────────

  bool get hasActiveSession => session != null;

  bool get isPaid => session?.isPaid ?? false;

  bool get isExpired => session?.isExpired ?? false;

  /// Total poses required by the selected frame.
  int get totalPoses => session?.poseCount ?? 1;

  /// How many photos have been captured so far.
  int get capturedCount => session?.photos.length ?? 0;

  bool get allPosesDone => session?.allPosesDone ?? false;

  /// Remaining session time (zero when not started or expired).
  Duration get remainingTime => session?.remainingTime ?? Duration.zero;

  /// Whether the current pose can still be retaken.
  bool get canRetakeCurrentPose =>
      session?.canRetakePose(currentPoseIndex) ?? false;

  SessionState copyWith({
    SessionModel? session,
    FrameModel? selectedFrame,
    FilterModel? selectedFilter,
    int? currentPoseIndex,
    bool? isMirrorEnabled,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return SessionState(
      session:          clearSession ? null : (session ?? this.session),
      selectedFrame:    clearSession ? null : (selectedFrame ?? this.selectedFrame),
      selectedFilter:   clearSession ? null : (selectedFilter ?? this.selectedFilter),
      currentPoseIndex: currentPoseIndex ?? this.currentPoseIndex,
      isMirrorEnabled:  isMirrorEnabled ?? this.isMirrorEnabled,
      isLoading:        isLoading ?? this.isLoading,
      error:            clearError ? null : (error ?? this.error),
    );
  }
}

// ── SessionNotifier ───────────────────────────────────────────────────────────

@riverpod
class SessionNotifier extends _$SessionNotifier {
  @override
  SessionState build() => const SessionState();

  // ── Session Lifecycle ─────────────────────────────────────────────────────

  /// Called after the backend confirms PAID and returns session data.
  /// This is where the 5-minute timer begins (business rule #3).
  void startSession({
    required int sessionId,
    required int eventId,
    required DateTime startedAt,
    required DateTime expiresAt,
  }) {
    final session = SessionModel(
      sessionId:  sessionId,
      eventId:    eventId,
      status:     'active',
      startedAt:  startedAt,
      expiresAt:  expiresAt,
    );
    state = state.copyWith(session: session, currentPoseIndex: 0);
  }

  /// Called after Frame Selection — saves frame_id, pose_count, and frame model.
  void setFrame({required int frameId, required int poseCount, FrameModel? frameModel}) {
    if (state.session == null) return;
    state = state.copyWith(
      selectedFrame: frameModel,
      session: state.session!.copyWith(
        frameId:   frameId,
        poseCount: poseCount,
      ),
    );
  }

  /// Called after a photo is captured for the current pose.
  void addPhoto(PhotoModel photo) {
    if (state.session == null) return;
    final updated = [...state.session!.photos, photo];
    state = state.copyWith(
      session: state.session!.copyWith(photos: updated),
    );
  }

  /// Increment the retake count for [poseIndex] and remove the previous photo.
  /// Called when customer presses RETAKE (max 2 per pose, business rule #7).
  void retakePose(int poseIndex) {
    if (state.session == null) return;
    if (!state.session!.canRetakePose(poseIndex)) return;

    // Remove the last photo for this pose slot and bump its retakeCount.
    final photos = List<PhotoModel>.from(state.session!.photos);
    if (poseIndex < photos.length) {
      final old = photos[poseIndex];
      photos[poseIndex] = old.copyWith(retakeCount: old.retakeCount + 1);
    }
    state = state.copyWith(
      session: state.session!.copyWith(
        photos: photos,
        retakeCount: state.session!.retakeCount + 1,
      ),
    );
  }

  /// Advance to the next pose slot.
  void nextPose() {
    state = state.copyWith(
      currentPoseIndex: state.currentPoseIndex + 1,
    );
  }

  /// Called after Filter Selection — saves chosen filter.
  void setFilter({
    required int filterId,
    required String filterName,
    FilterModel? filterModel,
  }) {
    if (state.session == null) return;
    state = state.copyWith(
      selectedFilter: filterModel,
      session: state.session!.copyWith(
        filterId:       filterId,
        selectedFilter: filterName,
      ),
    );
  }

  /// Called when backend returns the processed result (final_url, gif_url, qr_token).
  void setResult({
    required String finalUrl,
    required String gifUrl,
    required String qrToken,
  }) {
    if (state.session == null) return;
    state = state.copyWith(
      session: state.session!.copyWith(
        finalUrl: finalUrl,
        gifUrl:   gifUrl,
        qrToken:  qrToken,
      ),
    );
  }

  // ── UI State ──────────────────────────────────────────────────────────────

  void toggleMirror() =>
      state = state.copyWith(isMirrorEnabled: !state.isMirrorEnabled);

  void setLoading(bool loading) =>
      state = state.copyWith(isLoading: loading);

  void setError(String? error) =>
      state = state.copyWith(error: error);

  void clearError() =>
      state = state.copyWith(clearError: true);

  // ── Session Reset ─────────────────────────────────────────────────────────

  /// Full reset — clears ALL session data.
  /// Call when transitioning back to WelcomeScreen (Selesai or timeout).
  void resetSession() {
    state = const SessionState();
  }
}
