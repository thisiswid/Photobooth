import 'dart:async';
import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/frame/domain/models/frame_model.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';

// ── Step enum ─────────────────────────────────────────────────────────────────

/// Tahap proses pengambilan foto.
enum _CaptureStep {
  /// Step 1: Live preview kamera + toggle cermin + tombol Ambil Foto.
  frameAndPreview,
  /// Step 2: Hitung mundur 5 detik dengan circular progress & overlay kamera.
  countdown,
  /// Step 3: Proses pengambilan gambar sedang berlangsung.
  capturing,
  /// Step 4: Menampilkan hasil foto + opsi Retake / Pose Berikutnya.
  result,
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _uuid = Uuid();
const _countdownSeconds = 5;
const _maxRetake = 2;

/// Screen Sesi Foto — Redesigned matching `Detail halaman foto.png` & `UI Customer.png`.
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
  Timer? _uiRefreshTimer;

  // ── Current pose ──────────────────────────────────────────────────────────
  int _currentPose = 0; // 0-based index
  int _retakeCount = 0;
  XFile? _lastCaptured;
  List<XFile?> _capturedPhotos = [];
  bool _isMirrorEnabled = false;
  bool _showPoseTransitionBanner = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final controller = await CameraService.createController(
        resolution: ResolutionPreset.high,
      );
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      if (controller != null) {
        setState(() {
          _cameraController = controller;
          _isCameraReady = true;
        });
      } else {
        ErrorLogger.instance.logCameraError(
          message: 'Tidak ada perangkat kamera yang siap digunakan',
        );
      }
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal inisialisasi kamera: $e',
        stackTrace: stack,
      );
    }
  }

  // ── Flow transitions ──────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() {
      _step = _CaptureStep.countdown;
      _countdownValue = _countdownSeconds;
      _showPoseTransitionBanner = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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
        ErrorLogger.instance.logCameraError(
          message: 'Kamera belum siap saat capture dipicu (isCameraReady=false)',
        );
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _lastCaptured = null;
          _step = _CaptureStep.result;
        });
      }
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal mengambil gambar/takePicture: $e',
        stackTrace: stack,
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
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
      _lastCaptured = null;
      _step = _CaptureStep.frameAndPreview;
    });
  }

  void _onNext() {
    final notifier = ref.read(sessionNotifierProvider.notifier);
    final sessionId = ref.read(sessionNotifierProvider).session?.sessionId.toString() ?? '';

    // Simpan foto ke session
    notifier.addPhoto(PhotoModel(
      id: _uuid.v4(),
      sessionId: sessionId,
      fileUrl: _lastCaptured?.path ?? 'assets/mock/photo_placeholder.png',
      type: PhotoType.raw,
      capturedAt: DateTime.now(),
    ));

    final state = ref.read(sessionNotifierProvider);

    if (state.allPosesDone) {
      // Semua pose telah diambil → Lanjut ke Filter
      context.go(AppRoutes.filter);
    } else {
      // Lanjut ke pose berikutnya dengan animasi transisi
      setState(() {
        _capturedPhotos = [..._capturedPhotos, _lastCaptured];
        _currentPose++;
        _retakeCount = 0;
        _lastCaptured = null;
        _step = _CaptureStep.frameAndPreview;
        _showPoseTransitionBanner = true;
      });

      // Hilangkan banner penyemangat setelah 3 detik
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showPoseTransitionBanner = false);
        }
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
            // ── Pose Tabs Header ──────────────────────────────────────────
            if (totalPoses > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _PoseTabs(
                  current: _currentPose,
                  total: totalPoses,
                ),
              ),

            // ── Main Content Area ─────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildStage(totalPoses),
                  ),

                  // ── Pose Transition Toast / Banner ────────────────────────
                  if (_showPoseTransitionBanner)
                    Positioned(
                      top: 10.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _PoseTransitionToast(
                          currentPose: _currentPose + 1,
                          totalPoses: totalPoses,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStage(int totalPoses) {
    final selectedFrame = ref.watch(sessionNotifierProvider).selectedFrame;

    switch (_step) {
      case _CaptureStep.frameAndPreview:
        return _StepFrameAndPreview(
          cameraController: _isCameraReady ? _cameraController : null,
          frame: selectedFrame,
          isMirrorEnabled: _isMirrorEnabled,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
          onMirrorToggle: (val) => setState(() => _isMirrorEnabled = val),
          onStartPhoto: _startCountdown,
        );

      case _CaptureStep.countdown:
        return _StepCountdown(
          cameraController: _isCameraReady ? _cameraController : null,
          countdown: _countdownValue,
          isMirrorEnabled: _isMirrorEnabled,
          frame: selectedFrame,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
        );

      case _CaptureStep.capturing:
        return _StepCapturing(
          frame: selectedFrame,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
        );

      case _CaptureStep.result:
        return _StepResult(
          lastCaptured: _lastCaptured,
          capturedPhotos: _capturedPhotos,
          currentPose: _currentPose,
          totalPoses: totalPoses,
          frame: selectedFrame,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
          onRetake: _onRetake,
          onNext: _onNext,
        );
    }
  }
}

// ── Pose Tabs ─────────────────────────────────────────────────────────────────

class _PoseTabs extends StatelessWidget {
  const _PoseTabs({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final isDone = i < current;
          final isActive = i == current;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.darkBrown
                    : isDone
                        ? AppColors.buttonBrown.withValues(alpha: 0.85)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: isActive
                      ? AppColors.gold
                      : isDone
                          ? AppColors.gold.withValues(alpha: 0.5)
                          : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDone) ...[
                    Icon(Icons.check_circle_rounded, size: 13.sp, color: AppColors.gold),
                    SizedBox(width: 4.w),
                  ] else if (isActive) ...[
                    Container(
                      width: 6.r,
                      height: 6.r,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                  ],
                  Text(
                    'POSE ${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: isActive || isDone ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? AppColors.creamWhite
                          : isDone
                              ? AppColors.creamWhite.withValues(alpha: 0.9)
                              : AppColors.brown.withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Pose Transition Toast ─────────────────────────────────────────────────────

class _PoseTransitionToast extends StatelessWidget {
  const _PoseTransitionToast({
    required this.currentPose,
    required this.totalPoses,
  });

  final int currentPose;
  final int totalPoses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.darkBrown.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            'Pose $currentPose dari $totalPoses — Siapkan gaya terbaikmu!',
            style: GoogleFonts.inter(
              color: AppColors.creamWhite,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.6, duration: 400.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 300.ms);
  }
}

// ── Left Card: Photo Strip & Frame Preview ────────────────────────────────────

class _FrameSidebarCard extends StatelessWidget {
  const _FrameSidebarCard({
    required this.frame,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
    this.liveCameraPreview,
  });

  final FrameModel? frame;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;
  final Widget? liveCameraPreview;

  @override
  Widget build(BuildContext context) {
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

    return Container(
      width: 178.w,
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Badge: Frame Terpilih
          Container(
            margin: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.darkBrown.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.crop_original_rounded, size: 14.sp, color: AppColors.darkBrown),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    frame?.name ?? 'Frame Terpilih',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
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

          // Label Photo Strip + Counter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Photo Strip',
                  style: GoogleFonts.inter(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBrown,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${capturedPhotos.length}/$totalPoses',
                    style: GoogleFonts.inter(
                      fontSize: 9.5.sp,
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Photo Strip View with Dynamic Aspect Ratio & Live Stream in Active Slot
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 8.h),
              child: Center(
                child: PhotoStripWidget(
                  photos: displayPhotos,
                  frame: frame,
                  activePoseIndex: currentPose,
                  liveCameraPreview: liveCameraPreview,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Frame & Preview (Ambil Foto) ───────────────────────────────────────

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
  final ValueChanged<bool> onMirrorToggle;
  final VoidCallback onStartPhoto;

  @override
  Widget build(BuildContext context) {
    final isCamReady = cameraController != null && cameraController!.value.isInitialized;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Kiri: Card Photo Strip Frame Terpilih ─────────────────────────
          _FrameSidebarCard(
            frame: frame,
            capturedPhotos: capturedPhotos,
            currentPose: currentPose,
            totalPoses: totalPoses,
            liveCameraPreview: isCamReady
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

          SizedBox(width: 18.w),

          // ── Kanan: Viewfinder Kamera Utama & Kontrol Bawah ─────────────────
          Expanded(
            child: Column(
              children: [
                // Viewfinder Kamera Besar
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCoffee,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.darkBrown, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isCamReady)
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_camera_rounded,
                                      size: 54.sp,
                                      color: AppColors.paper.withValues(alpha: 0.35),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Menyiapkan Kamera...',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        color: AppColors.creamWhite.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Pose Watermark Indicator di pojok kiri atas kamera
                          Positioned(
                            top: 14.h,
                            left: 16.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined, color: AppColors.gold, size: 12.sp),
                                  SizedBox(width: 5.w),
                                  Text(
                                    'POSE ${currentPose + 1} OF $totalPoses',
                                    style: GoogleFonts.inter(
                                      color: AppColors.creamWhite,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Baris Kontrol Bawah (Cermin + Mulai Foto)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sisi Kiri: Cermin Toggle
                    Text(
                      'Cermin',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _MirrorTogglePill(
                      isMirrored: isMirrorEnabled,
                      onChanged: onMirrorToggle,
                    ),

                    const Spacer(),

                    // Sisi Kanan: Tombol AMBIL / MULAI FOTO
                    SizedBox(
                      width: 210.w,
                      height: 52.h,
                      child: ElevatedButton.icon(
                        onPressed: onStartPhoto,
                        icon: Icon(Icons.camera_alt_rounded, size: 20.sp, color: AppColors.creamWhite),
                        label: Text(
                          'MULAI FOTO',
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
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
                            side: const BorderSide(color: AppColors.gold, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Keterangan Sesi di Bagian Bawah
                _SessionInfoPill(retakeCount: retakeCount, maxRetake: maxRetake),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mirror Toggle Pill ────────────────────────────────────────────────────────

class _MirrorTogglePill extends StatelessWidget {
  const _MirrorTogglePill({
    required this.isMirrored,
    required this.onChanged,
  });

  final bool isMirrored;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TogglePillOption(
            label: 'MIRROR',
            icon: Icons.flip_rounded,
            isActive: isMirrored,
            onTap: () => onChanged(true),
          ),
          SizedBox(width: 2.w),
          _TogglePillOption(
            label: 'NO MIRROR',
            icon: Icons.crop_original_rounded,
            isActive: !isMirrored,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _TogglePillOption extends StatelessWidget {
  const _TogglePillOption({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive ? AppColors.darkBrown : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.sp,
              color: isActive ? AppColors.gold : AppColors.brown.withValues(alpha: 0.7),
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.creamWhite : AppColors.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session Info Pill ─────────────────────────────────────────────────────────

class _SessionInfoPill extends StatelessWidget {
  const _SessionInfoPill({required this.retakeCount, required this.maxRetake});

  final int retakeCount;
  final int maxRetake;

  @override
  Widget build(BuildContext context) {
    final sisaRetake = maxRetake - retakeCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '1 sesi foto: 5 menit',
            style: GoogleFonts.inter(
              fontSize: 10.5.sp,
              color: AppColors.brown,
              fontWeight: FontWeight.w500,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Container(
              width: 3.5.r,
              height: 3.5.r,
              decoration: const BoxDecoration(
                color: AppColors.lightBrown,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            'Maksimal 2 kali retake per pose (Sisa: $sisaRetake)',
            style: GoogleFonts.inter(
              fontSize: 10.5.sp,
              color: sisaRetake <= 0 ? AppColors.error : AppColors.brown,
              fontWeight: sisaRetake <= 0 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Countdown 5 Detik ─────────────────────────────────────────────────

class _StepCountdown extends StatelessWidget {
  const _StepCountdown({
    required this.cameraController,
    required this.countdown,
    required this.isMirrorEnabled,
    required this.frame,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
  });

  final CameraController? cameraController;
  final int countdown;
  final bool isMirrorEnabled;
  final FrameModel? frame;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;

  @override
  Widget build(BuildContext context) {
    final isCamReady = cameraController != null && cameraController!.value.isInitialized;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sisi Kiri: Photo Strip Frame
          _FrameSidebarCard(
            frame: frame,
            capturedPhotos: capturedPhotos,
            currentPose: currentPose,
            totalPoses: totalPoses,
            liveCameraPreview: isCamReady
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

          SizedBox(width: 18.w),

          // Sisi Kanan: Viewfinder dengan Overlay Countdown Melingkar
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCoffee,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.darkBrown, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Live camera preview
                          if (isCamReady)
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

                          // Dim overlay semi-transparan
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),

                          // Center Ring & Countdown Number & "BERSIAP YA!"
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 130.r,
                                  height: 130.r,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Circular Progress Indicator
                                      SizedBox(
                                        width: 130.r,
                                        height: 130.r,
                                        child: CircularProgressIndicator(
                                          value: countdown / _countdownSeconds,
                                          strokeWidth: 6,
                                          backgroundColor: Colors.white24,
                                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                                        ),
                                      ),

                                      // Big Countdown Number
                                      Text(
                                        '$countdown',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 64.sp,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.creamWhite,
                                          shadows: [
                                            const Shadow(color: Colors.black87, blurRadius: 16),
                                          ],
                                        ),
                                      )
                                          .animate(key: ValueKey(countdown))
                                          .scale(begin: const Offset(1.3, 1.3), duration: 350.ms, curve: Curves.easeOutBack)
                                          .fadeIn(duration: 150.ms),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  'BERSIAP YA!',
                                  style: GoogleFonts.inter(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: AppColors.creamWhite,
                                    shadows: [
                                      const Shadow(color: Colors.black87, blurRadius: 12),
                                    ],
                                  ),
                                ).animate().fadeIn(duration: 300.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Info banner tetap ada agar tata letak stabil
                const _SessionInfoPill(retakeCount: 0, maxRetake: _maxRetake),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Foto Sedang Diambil (Capturing) ───────────────────────────────────

class _StepCapturing extends StatelessWidget {
  const _StepCapturing({
    required this.frame,
    required this.capturedPhotos,
    required this.currentPose,
    required this.totalPoses,
  });

  final FrameModel? frame;
  final List<XFile?> capturedPhotos;
  final int currentPose;
  final int totalPoses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sisi Kiri: Frame sidebar
          _FrameSidebarCard(
            frame: frame,
            capturedPhotos: capturedPhotos,
            currentPose: currentPose,
            totalPoses: totalPoses,
          ),

          SizedBox(width: 18.w),

          // Sisi Kanan: Box Sedang Mengambil Foto
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.creamWhite,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.borderWarm, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80.r,
                            height: 80.r,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.darkBrown,
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: AppColors.creamWhite, size: 40.sp),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 500.ms),
                          SizedBox(height: 20.h),
                          Text(
                            'FOTO SEDANG DIAMBIL',
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.darkBrown,
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                          SizedBox(height: 6.h),
                          Text(
                            'Mohon diam sebentar ya',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: AppColors.brown,
                            ),
                          ).animate().fadeIn(delay: 150.ms),
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: 28.r,
                            height: 28.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.darkBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                const _SessionInfoPill(retakeCount: 0, maxRetake: _maxRetake),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Hasil Foto & Action Buttons ────────────────────────────────────────

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

    // List foto termasuk yang baru diambil
    final List<XFile?> allPhotosWithCurrent = [...capturedPhotos, lastCaptured];

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sisi Kiri: Photo Strip Frame dengan foto yang baru saja terisi
          _FrameSidebarCard(
            frame: frame,
            capturedPhotos: allPhotosWithCurrent,
            currentPose: currentPose,
            totalPoses: totalPoses,
          ),

          SizedBox(width: 18.w),

          // Sisi Kanan: Preview Hasil Foto Besar & Tombol Aksi di Bawah
          Expanded(
            child: Column(
              children: [
                // Display Foto yang Baru Diambil
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.borderWarm, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(12.r),
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
                                color: AppColors.creamWhite,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 48.sp,
                                  color: AppColors.brown,
                                ),
                              ),
                            ),
                    ),
                  ).animate().scale(begin: const Offset(0.96, 0.96), duration: 350.ms).fadeIn(),
                ),

                SizedBox(height: 14.h),

                // Tombol Aksi Horizontal: RETAKE & NEXT / PILIH FILTER
                Row(
                  children: [
                    // Tombol RETAKE
                    if (canRetake) ...[
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 52.h,
                          child: OutlinedButton.icon(
                            onPressed: onRetake,
                            icon: Icon(Icons.refresh_rounded, size: 20.sp, color: AppColors.darkBrown),
                            label: Text(
                              'RETAKE (${maxRetake - retakeCount})',
                              style: GoogleFonts.inter(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBrown,
                                letterSpacing: 0.8,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.darkBrown, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              backgroundColor: AppColors.creamWhite,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                    ],

                    // Tombol NEXT / POSE BERIKUT / PILIH FILTER
                    Expanded(
                      flex: canRetake ? 2 : 1,
                      child: SizedBox(
                        height: 52.h,
                        child: ElevatedButton.icon(
                          onPressed: onNext,
                          icon: Icon(
                            isLastPose ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                            size: 20.sp,
                            color: AppColors.creamWhite,
                          ),
                          label: Text(
                            isLastPose ? 'PILIH FILTER' : 'POSE BERIKUT',
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.creamWhite,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonBrown,
                            foregroundColor: AppColors.creamWhite,
                            elevation: 4,
                            shadowColor: AppColors.darkBrown.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              side: const BorderSide(color: AppColors.gold, width: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Keterangan Sesi di Bawah
                _SessionInfoPill(retakeCount: retakeCount, maxRetake: maxRetake),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
