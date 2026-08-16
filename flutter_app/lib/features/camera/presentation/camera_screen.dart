import 'dart:async';
import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/frame/domain/models/frame_model.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/responsive_button.dart';

// ── Step enum ─────────────────────────────────────────────────────────────────

/// 5 tahap proses foto dalam satu screen.
enum _CaptureStep {
  /// Step 1: Pilih frame + preview kamera live + tombol Mulai Foto.
  frameAndPreview,
  /// Step 2: Countdown 5 detik dengan kamera gelap + teks "BERSIAP YA!".
  countdown,
  /// Step 3: Foto sedang diambil — icon kamera + teks proses.
  capturing,
  /// Step 4: Hasil foto tampil + frame terpilih + Retake / Next.
  result,
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _uuid = Uuid();
const _countdownSeconds = 5;
const _maxRetake = 2;

/// Screen 5 — Sesi Foto.
/// Header transparan centered 2x.
/// Flow 5-step: Pilih Frame → Countdown → Mengambil → Hasil → Pose Berikutnya.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── Flow state ────────────────────────────────────────────────────────────
  _CaptureStep _step = _CaptureStep.frameAndPreview;
  int _countdownValue = _countdownSeconds;
  Timer? _countdownTimer;

  // ── Current pose ──────────────────────────────────────────────────────────
  int _currentPose = 0;     // 0-based
  int _retakeCount = 0;
  XFile? _lastCaptured;
  List<XFile?> _capturedPhotos = [];
  bool _isMirrorEnabled = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return; }
      setState(() { _cameraController = controller; _isCameraReady = true; });
    } catch (_) {}
  }

  // ── Flow transitions ──────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() { _step = _CaptureStep.countdown; _countdownValue = _countdownSeconds; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
      } else {
        t.cancel();
        _capturePhoto();
      }
    });
  }

  Future<void> _capturePhoto() async {
    setState(() => _step = _CaptureStep.capturing);
    if (!mounted) return;

    try {
      if (_cameraController != null && _isCameraReady) {
        final file = await _cameraController!.takePicture();
        if (!mounted) return;
        setState(() {
          _lastCaptured = file;
          _step = _CaptureStep.result;
        });
      } else {
        // Kamera belum siap — fallback tanpa foto
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _lastCaptured = null;
          _step = _CaptureStep.result;
        });
      }
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _lastCaptured = null;
        _step = _CaptureStep.result;
      });
    }
  }

  void _onRetake() {
    if (_retakeCount >= _maxRetake) return;
    setState(() {
      _retakeCount++;
      _step = _CaptureStep.frameAndPreview;
    });
  }

  void _onNext() {
    final notifier = ref.read(sessionNotifierProvider.notifier);
    final sessionId = ref.read(sessionNotifierProvider).session?.sessionId.toString() ?? '';

    // Simpan foto ke session — pakai path file asli jika ada, fallback ke placeholder
    notifier.addPhoto(PhotoModel(
      id: _uuid.v4(),
      sessionId: sessionId,
      fileUrl: _lastCaptured?.path ?? 'assets/mock/photo_placeholder.png',
      type: PhotoType.raw,
      capturedAt: DateTime.now(),
    ));

    final state = ref.read(sessionNotifierProvider);

    if (state.allPosesDone) {
      // Semua pose selesai → ke filter
      context.go(AppRoutes.filter);
    } else {
      // Pose berikutnya
      setState(() {
        _capturedPhotos = [..._capturedPhotos, _lastCaptured];
        _currentPose++;
        _retakeCount = 0;
        _lastCaptured = null;
        _step = _CaptureStep.frameAndPreview;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final totalPoses = sessionState.totalPoses;
    final remaining = sessionState.remainingTime;
    final timerText =
        '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final isTimerWarning = remaining.inSeconds < 60;

    return PopScope(
      canPop: false,
      child: PhotoboothLayout(
        showDecorations: _step != _CaptureStep.countdown,
        header: CustomerHeader(
          trailing: TimerChip(text: timerText, isWarning: isTimerWarning),
        ),
        child: Column(
          children: [
            // ── Pose indicator ──────────────────────────────────────────
            _PoseIndicator(current: _currentPose, total: totalPoses),

            SizedBox(height: 6.h),

            // ── Main content (changes per step) ────────────────────────
            Expanded(child: _buildStep(totalPoses)),

            // ── Progress bar ────────────────────────────────────────────
            _ProgressBar(step: _step, currentPose: _currentPose, totalPoses: totalPoses),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int totalPoses) {
    switch (_step) {
      case _CaptureStep.frameAndPreview:
        return _StepFrameAndPreview(
          cameraController: _isCameraReady ? _cameraController : null,
          frame: ref.watch(sessionNotifierProvider).selectedFrame,
          isMirrorEnabled: _isMirrorEnabled,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
          onMirrorToggle: () => setState(() => _isMirrorEnabled = !_isMirrorEnabled),
          onStartPhoto: _startCountdown,
        );
      case _CaptureStep.countdown:
        return _StepCountdown(
          cameraController: _isCameraReady ? _cameraController : null,
          countdown: _countdownValue,
          isMirrorEnabled: _isMirrorEnabled,
          frame: ref.watch(sessionNotifierProvider).selectedFrame,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
        );
      case _CaptureStep.capturing:
        return const _StepCapturing();
      case _CaptureStep.result:
        return _StepResult(
          lastCaptured: _lastCaptured,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
          frame: ref.watch(sessionNotifierProvider).selectedFrame,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
          onRetake: _onRetake,
          onNext: _onNext,
        );
    }
  }
}

// ── Pose Indicator ────────────────────────────────────────────────────────────

class _PoseIndicator extends StatelessWidget {
  const _PoseIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == current ? 36.w : 14.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.darkBrown : AppColors.borderWarm,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: i == current ? AppColors.gold : Colors.transparent,
                width: 1,
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.currentPose, required this.totalPoses});
  final _CaptureStep step;
  final int currentPose;
  final int totalPoses;

  static const _labels = [
    'Preview', 'Countdown', 'Foto Diambil', 'Hasil Foto',
  ];

  @override
  Widget build(BuildContext context) {
    final stepIndex = _CaptureStep.values.indexOf(step);
    return Container(
      height: 36.h,
      color: AppColors.creamWhite.withValues(alpha: 0.9),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: _CaptureStep.values.asMap().entries.map((e) {
          final isActive = e.key == stepIndex;
          final isDone = e.key < stepIndex;
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              padding: EdgeInsets.symmetric(vertical: 4.h),
              decoration: BoxDecoration(
                color: isDone ? AppColors.darkBrown
                    : isActive ? AppColors.buttonBrown
                    : AppColors.borderWarm,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                  color: isActive ? AppColors.gold : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  _labels[e.key],
                  style: TextStyle(
                    fontSize: 9.sp, fontWeight: FontWeight.w700,
                    color: (isDone || isActive) ? AppColors.creamWhite : AppColors.brown,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Step 1: Frame & Preview (Vintage Coffee Layout) ──────────────────────────

class _StepFrameAndPreview extends StatelessWidget {
  const _StepFrameAndPreview({
    required this.cameraController,
    required this.frame,
    required this.isMirrorEnabled,
    required this.retakeCount,
    required this.maxRetake,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
    required this.onMirrorToggle,
    required this.onStartPhoto,
  });

  final CameraController? cameraController;
  final FrameModel? frame;
  final bool isMirrorEnabled;
  final int retakeCount;
  final int maxRetake;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;
  final VoidCallback onMirrorToggle;
  final VoidCallback onStartPhoto;

  @override
  Widget build(BuildContext context) {
    // List foto yang sudah diambil untuk live photo strip di kiri
    final List<PhotoModel> displayPhotos = [];
    for (int i = 0; i < capturedPhotos.length; i++) {
      if (capturedPhotos[i] != null) {
        displayPhotos.add(PhotoModel(
          id: 'pose_$i',
          sessionId: '',
          fileUrl: capturedPhotos[i]!.path,
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Row(
        children: [
          // ── Kiri: Vintage Card (Photo Strip Frame Asli) ───────────────────
          Container(
            width: 175.w,
            decoration: BoxDecoration(
              color: AppColors.creamWhite,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Frame Badge
                Container(
                  margin: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.darkBrown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10.r, height: 10.r,
                        decoration: const BoxDecoration(
                          color: AppColors.gold, shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          frame?.name ?? 'Strip Klasik',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Label "Strip Preview"
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Photo Strip', style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700, color: AppColors.darkBrown,
                      )),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('${capturedPhotos.length}/$totalPoses',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.darkBrown,
                            fontWeight: FontWeight.w700,
                          )),
                      ),
                    ],
                  ),
                ),

                // Photo Strip Frame Asli (Rasio dinamis sesuai frame + Live Camera di slot aktif)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 6.h),
                    child: Center(
                      child: PhotoStripWidget(
                        photos: displayPhotos,
                        frame: frame,
                        activePoseIndex: currentPose - 1,
                        liveCameraPreview: (cameraController != null && cameraController!.value.isInitialized)
                            ? Transform.flip(
                                flipX: isMirrorEnabled,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: cameraController!.value.previewSize?.width ?? 1280,
                                    height: cameraController!.value.previewSize?.height ?? 720,
                                    child: CameraPreview(cameraController!),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Retake info
                Container(
                  margin: EdgeInsets.fromLTRB(8.r, 0, 8.r, 8.r),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: retakeCount >= maxRetake
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.cream,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: retakeCount >= maxRetake ? AppColors.error : AppColors.borderWarm,
                    ),
                  ),
                  child: Text(
                    'Retake: $retakeCount/$maxRetake',
                    style: AppTextStyles.caption.copyWith(
                      color: retakeCount >= maxRetake ? AppColors.error : AppColors.darkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 14.w),

          // ── Kanan: Large Viewfinder Kamera + Tombol Ambil Foto ─────────────
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCoffee,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: AppColors.darkBrown, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Live Camera Preview (Proporsional, tidak gepeng)
                          if (cameraController != null && cameraController!.value.isInitialized)
                            Center(
                              child: Transform.flip(
                                flipX: isMirrorEnabled,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: cameraController!.value.previewSize?.width ?? 1280,
                                    height: cameraController!.value.previewSize?.height ?? 720,
                                    child: CameraPreview(cameraController!),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.darkCoffee,
                              child: Center(
                                child: Icon(Icons.camera_alt_rounded,
                                    color: AppColors.paper.withValues(alpha: 0.4), size: 64.sp),
                              ),
                            ),

                          // Floating Vintage Mirror / No Mirror Toggle
                          Positioned(
                            bottom: 14.h,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(3.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.creamWhite.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(color: AppColors.borderWarm),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.darkBrown.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MirrorButton(
                                        label: 'Mirror',
                                        isActive: isMirrorEnabled,
                                        onTap: isMirrorEnabled ? null : onMirrorToggle,
                                      ),
                                      SizedBox(width: 4.w),
                                      _MirrorButton(
                                        label: 'No Mirror',
                                        isActive: !isMirrorEnabled,
                                        onTap: !isMirrorEnabled ? null : onMirrorToggle,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // Tombol AMBIL FOTO (Vintage Brown & Gold)
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: onStartPhoto,
                    icon: Icon(Icons.camera_alt_rounded, size: 22.sp, color: AppColors.creamWhite),
                    label: Text(
                      'AMBIL FOTO',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.creamWhite,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonBrown,
                      foregroundColor: AppColors.creamWhite,
                      elevation: 4,
                      shadowColor: AppColors.darkBrown.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        side: const BorderSide(color: AppColors.gold, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MirrorButton extends StatelessWidget {
  const _MirrorButton({required this.label, required this.isActive, this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive ? AppColors.darkBrown : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.creamWhite : AppColors.darkBrown,
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Countdown ─────────────────────────────────────────────────────────

class _StepCountdown extends StatelessWidget {
  const _StepCountdown({
    required this.cameraController,
    required this.countdown,
    required this.isMirrorEnabled,
    this.frame,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
    required this.retakeCount,
    required this.maxRetake,
  });

  final CameraController? cameraController;
  final int countdown;
  final bool isMirrorEnabled;
  final FrameModel? frame;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;
  final int retakeCount;
  final int maxRetake;

  @override
  Widget build(BuildContext context) {
    // List foto yang sudah diambil untuk live photo strip di kiri
    final List<PhotoModel> displayPhotos = [];
    for (int i = 0; i < capturedPhotos.length; i++) {
      if (capturedPhotos[i] != null) {
        displayPhotos.add(PhotoModel(
          id: 'pose_$i',
          sessionId: '',
          fileUrl: capturedPhotos[i]!.path,
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Row(
        children: [
          // ── Kiri: Vintage Card (Photo Strip Frame Asli + Live Camera Feed di slot aktif) ──
          Container(
            width: 175.w,
            decoration: BoxDecoration(
              color: AppColors.creamWhite,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Frame Badge
                Container(
                  margin: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.darkBrown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo_filter_rounded, size: 14.sp, color: AppColors.darkBrown),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          frame?.name ?? 'Classic Strip',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Label "Strip Preview"
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Photo Strip', style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700, color: AppColors.darkBrown,
                      )),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('${capturedPhotos.length}/$totalPoses',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.darkBrown,
                            fontWeight: FontWeight.w700,
                          )),
                      ),
                    ],
                  ),
                ),

                // Photo Strip Frame Asli (Live Camera di slot aktif)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 6.h),
                    child: Center(
                      child: PhotoStripWidget(
                        photos: displayPhotos,
                        frame: frame,
                        activePoseIndex: currentPose - 1,
                        liveCameraPreview: (cameraController != null && cameraController!.value.isInitialized)
                            ? Transform.flip(
                                flipX: isMirrorEnabled,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: cameraController!.value.previewSize?.width ?? 1280,
                                    height: cameraController!.value.previewSize?.height ?? 720,
                                    child: CameraPreview(cameraController!),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Retake info
                Container(
                  margin: EdgeInsets.fromLTRB(8.r, 0, 8.r, 8.r),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: retakeCount >= maxRetake
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.cream,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: retakeCount >= maxRetake ? AppColors.error : AppColors.borderWarm,
                    ),
                  ),
                  child: Text(
                    'Retake: $retakeCount/$maxRetake',
                    style: AppTextStyles.caption.copyWith(
                      color: retakeCount >= maxRetake ? AppColors.error : AppColors.darkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 14.w),

          // ── Kanan: Viewfinder Kamera dengan Countdown Overlay ─────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkCoffee,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppColors.darkBrown, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBrown.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Live camera view
                    if (cameraController != null && cameraController!.value.isInitialized)
                      Center(
                        child: Transform.flip(
                          flipX: isMirrorEnabled,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: cameraController!.value.previewSize?.width ?? 1280,
                              height: cameraController!.value.previewSize?.height ?? 720,
                              child: CameraPreview(cameraController!),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(color: AppColors.darkCoffee),

                    // Warm Coffee Dim Overlay
                    Container(color: AppColors.darkCoffee.withValues(alpha: 0.4)),

                    // "BERSIAP YA!" di tengah
                    Center(
                      child: Text(
                        'BERSIAP YA!',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppColors.creamWhite,
                          fontSize: 32.sp,
                          letterSpacing: 4,
                          shadows: [
                            const Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                    ),

                    // Countdown di kanan atas
                    Positioned(
                      top: 20.h,
                      right: 24.w,
                      child: Text(
                        '$countdown',
                        style: AppTextStyles.countdownNumber.copyWith(
                          color: AppColors.gold,
                          fontSize: 84.sp,
                          shadows: [
                            const Shadow(color: Colors.black87, blurRadius: 20),
                          ],
                        ),
                      )
                          .animate(key: ValueKey(countdown))
                          .scale(begin: const Offset(1.3, 1.3), duration: 400.ms)
                          .fadeIn(duration: 200.ms),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Capturing ─────────────────────────────────────────────────────────

class _StepCapturing extends StatelessWidget {
  const _StepCapturing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 32.h),
        decoration: BoxDecoration(
          color: AppColors.creamWhite,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.borderWarm, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBrown.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_rounded, size: 72.sp, color: AppColors.darkBrown)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 500.ms),
            SizedBox(height: 20.h),
            Text(
              'FOTO SEDANG DIAMBIL',
              style: AppTextStyles.headlineMedium.copyWith(letterSpacing: 2),
            ).animate().fadeIn(duration: 400.ms),
            SizedBox(height: 8.h),
            Text(
              'Mohon diam sebentar ya',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.brown),
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 28.h),
            SizedBox(
              width: 32.r, height: 32.r,
              child: const CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.darkBrown),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Result ────────────────────────────────────────────────────────────

class _StepResult extends StatelessWidget {
  const _StepResult({
    required this.lastCaptured,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
    required this.frame,
    required this.retakeCount,
    required this.maxRetake,
    required this.onRetake,
    required this.onNext,
  });

  final XFile? lastCaptured;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;
  final FrameModel? frame;
  final int retakeCount;
  final int maxRetake;
  final VoidCallback onRetake;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canRetake = retakeCount < maxRetake;
    final isLastPose = currentPose + 1 >= totalPoses;

    // Susun list foto yang sudah diambil sampai pose ini
    final List<PhotoModel> displayPhotos = [];
    for (int i = 0; i < currentPose; i++) {
      if (i < capturedPhotos.length && capturedPhotos[i] != null) {
        displayPhotos.add(PhotoModel(
          id: 'pose_$i',
          sessionId: '',
          fileUrl: capturedPhotos[i]!.path,
        ));
      }
    }
    if (lastCaptured != null) {
      displayPhotos.add(PhotoModel(
        id: 'pose_$currentPose',
        sessionId: '',
        fileUrl: lastCaptured!.path,
      ));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Row(
        children: [
          // ── Preview foto terakhir (tanpa frame) ─────────────────────
          Expanded(
            flex: 3,
            child: Center(
              child: lastCaptured != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.file(
                        dart_io.File(lastCaptured!.path),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.borderWarm),
                      ),
                      child: Center(
                        child: Icon(Icons.camera_alt_outlined,
                            size: 48.sp, color: AppColors.brown),
                      ),
                    ),
            ),
          ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms).fadeIn(),

          SizedBox(width: 20.w),

          // ── Tombol Retake / Lanjut ───────────────────────────────────
          SizedBox(
            width: 200.w,
            child: Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.creamWhite,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderWarm, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBrown.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.darkBrown.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      'Pose ${currentPose + 1} / $totalPoses',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.darkBrown,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Foto berhasil diambil!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Retake tersisa: ${maxRetake - retakeCount}/$maxRetake',
                    style: AppTextStyles.caption.copyWith(color: AppColors.brown),
                  ),
                  SizedBox(height: 24.h),
                  if (canRetake) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ResponsiveButton(
                        label: 'Foto Ulang',
                        icon: Icons.refresh_rounded,
                        onPressed: onRetake,
                        variant: ButtonVariant.outlined,
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ResponsiveButton(
                      label: isLastPose ? 'PILIH FILTER' : 'POSE BERIKUT',
                      icon: isLastPose ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideX(begin: 0.1, delay: 150.ms).fadeIn(delay: 150.ms),
        ],
      ),
    );
  }
}
