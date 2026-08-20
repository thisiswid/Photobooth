import 'dart:async';
import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
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
import '../../../shared/widgets/responsive_layout_builder.dart';

// ── Flow Step enum ────────────────────────────────────────────────────────────

enum _CaptureStep {
  /// Step 1: Live camera view + [ Mirror/No Mirror toggle ] [ Mulai ]
  initialPreview,
  /// Step 2: Clean countdown
  countdown,
  /// Step 3: Capturing photo
  capturing,
  /// Step 4: Reviewing captured photo with [ Retake ] [ Lanjut ]
  result,
}

const _uuid = Uuid();
const _countdownSeconds = 7;

/// Clean, minimal, vintage, and natural Photobooth Camera Screen.
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
  _CaptureStep _step = _CaptureStep.initialPreview;
  int _countdownValue = _countdownSeconds;
  Timer? _countdownTimer;
  Timer? _uiRefreshTimer;

  // ── Poses state ───────────────────────────────────────────────────────────
  int _currentPose = 0;
  XFile? _lastCaptured;
  List<XFile?> _capturedPhotos = [];
  bool _isMirrorEnabled = false;

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
      }
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal inisialisasi kamera: $e',
        stackTrace: stack,
      );
    }
  }

  // ── Flow Actions ──────────────────────────────────────────────────────────

  void _startCountdown() {
    ref.read(sessionNotifierProvider.notifier).setMirror(_isMirrorEnabled);
    setState(() {
      _step = _CaptureStep.countdown;
      _countdownValue = _countdownSeconds;
    });

    _countdownTimer?.cancel();
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
        final rawFile = await _cameraController!.takePicture();
        if (!mounted) return;

        final processedFile = await _processCapturedPhoto(rawFile, _isMirrorEnabled);

        if (!mounted) return;
        setState(() {
          _lastCaptured = processedFile;
          _step = _CaptureStep.result;
        });
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        setState(() {
          _lastCaptured = null;
          _step = _CaptureStep.result;
        });
      }
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal mengambil gambar: $e',
        stackTrace: stack,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _lastCaptured = null;
        _step = _CaptureStep.result;
      });
    }
  }

  Future<XFile> _processCapturedPhoto(XFile rawFile, bool isMirrored) async {
    try {
      final bytes = await rawFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return rawFile;

      final isFrontCam = _cameraController?.description.lensDirection == CameraLensDirection.front;

      img.Image processed = decoded;
      if (isFrontCam) {
        if (!isMirrored) {
          processed = img.flipHorizontal(processed);
        }
      } else {
        if (isMirrored) {
          processed = img.flipHorizontal(processed);
        }
      }

      final newBytes = img.encodeJpg(processed, quality: 95);
      final processedFile = dart_io.File(rawFile.path)..writeAsBytesSync(newBytes);
      return XFile(processedFile.path);
    } catch (e) {
      return rawFile;
    }
  }

  void _onRetake() {
    setState(() {
      _lastCaptured = null;
    });
    _startCountdown();
  }

  void _onNext() {
    final notifier = ref.read(sessionNotifierProvider.notifier);
    final sessionId = ref.read(sessionNotifierProvider).session?.sessionId.toString() ?? '1';

    if (_lastCaptured != null) {
      notifier.addPhoto(PhotoModel(
        id: _uuid.v4(),
        sessionId: sessionId,
        fileUrl: _lastCaptured!.path,
        type: PhotoType.raw,
        capturedAt: DateTime.now(),
      ));
    }

    final totalPoses = ref.read(sessionNotifierProvider).totalPoses;
    final nextPoseIndex = _currentPose + 1;

    setState(() {
      _capturedPhotos = [..._capturedPhotos, _lastCaptured];
      _lastCaptured = null;
    });

    if (nextPoseIndex >= totalPoses) {
      context.go(AppRoutes.filter);
    } else {
      setState(() {
        _currentPose = nextPoseIndex;
      });
      _startCountdown();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final selectedFrame = sessionState.selectedFrame;
    final isMobile = context.isMobile;

    return PopScope(
      canPop: false,
      child: PhotoboothLayout(
        showDecorations: true,
        header: const CustomerHeader(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 10.w : 20.w,
            4.h,
            isMobile ? 10.w : 20.w,
            10.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── KIRI: Preview Frame Strip — tanpa card, flex 1 ─────────────
              Expanded(
                flex: 1,
                child: _FrameStripPreview(
                  frame: selectedFrame,
                  capturedPhotos: _step == _CaptureStep.result
                      ? [..._capturedPhotos, _lastCaptured]
                      : _capturedPhotos,
                  currentPoseIndex: _currentPose,
                  liveCameraPreview: (_step == _CaptureStep.initialPreview || _step == _CaptureStep.countdown) && _isCameraReady
                      ? Transform.flip(
                          flipX: _isMirrorEnabled,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cameraController!.value.previewSize?.width ?? 1280,
                              height: _cameraController!.value.previewSize?.height ?? 720,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        )
                      : null,
                ),
              ),

              SizedBox(width: isMobile ? 10.w : 16.w),

              // ── KANAN: Viewfinder + Controls — flex 2 ─────────────────────
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Main Camera Box / Photo Result Box
                    Expanded(
                      child: Center(
                        child: _buildCenterContent(),
                      ),
                    ),

                    SizedBox(height: isMobile ? 8.h : 12.h),

                    // Bottom Action Controls — lebar = lebar viewfinder
                    _buildBottomControls(isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Center Content (Live View / Countdown / Review Result) ────────────────

  Widget _buildCenterContent() {
    switch (_step) {
      case _CaptureStep.initialPreview:
        return _buildCameraViewfinder(showOverlay: false);

      case _CaptureStep.countdown:
        return _buildCameraViewfinder(
          showOverlay: true,
          overlayChild: _buildCleanCountdownOverlay(),
        );

      case _CaptureStep.capturing:
        return _buildCameraViewfinder(
          showOverlay: true,
          overlayChild: const Center(
            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
          ),
        );

      case _CaptureStep.result:
        return _buildPhotoResultDisplay();
    }
  }

  Widget _buildCameraViewfinder({required bool showOverlay, Widget? overlayChild}) {
    final previewW = _cameraController?.value.previewSize?.width ?? 720;
    final previewH = _cameraController?.value.previewSize?.height ?? 1280;
    final aspectRatio = previewW / previewH;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCoffee,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.darkBrown, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBrown.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isCameraReady && _cameraController != null)
                Center(
                  child: Transform.flip(
                    flipX: _isMirrorEnabled,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewW,
                        height: previewH,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.darkCoffee,
                  child: Center(
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 42.sp,
                      color: AppColors.paper.withValues(alpha: 0.35),
                    ),
                  ),
                ),

              if (showOverlay) ...[
                Container(color: Colors.black.withValues(alpha: 0.55)),
                if (overlayChild != null) overlayChild,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanCountdownOverlay() {
    return Center(
      child: SizedBox(
        width: 140.r,
        height: 140.r,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140.r,
              height: 140.r,
              child: CircularProgressIndicator(
                value: _countdownValue / _countdownSeconds,
                strokeWidth: 4.5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            Text(
              '$_countdownValue',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 72.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.creamWhite,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 16),
                ],
              ),
            )
                .animate(key: ValueKey(_countdownValue))
                .scale(begin: const Offset(1.25, 1.25), duration: 300.ms, curve: Curves.easeOut)
                .fadeIn(duration: 150.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoResultDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCoffee,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.darkBrown, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: _lastCaptured != null
            ? Image.file(
                dart_io.File(_lastCaptured!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48.sp,
                  color: AppColors.paper.withValues(alpha: 0.4),
                ),
              ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ── Bottom Action Controls ────────────────────────────────────────────────

  Widget _buildBottomControls(bool isMobile) {
    if (_step == _CaptureStep.initialPreview) {
      // ── [Mirror/No Mirror 50%] [Mulai 50%] ───────────────────────────────
      return Row(
        children: [
          // Toggle Mirror — 50% lebar
          Expanded(
            child: _MirrorToggleButton(
              isMirrorEnabled: _isMirrorEnabled,
              onTap: () => setState(() => _isMirrorEnabled = !_isMirrorEnabled),
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 8.w : 12.w),
          // Mulai — 50% lebar
          Expanded(
            child: _PrimaryButton(
              label: 'Mulai',
              onTap: _startCountdown,
              isMobile: isMobile,
            ),
          ),
        ],
      );
    }

    if (_step == _CaptureStep.result) {
      // ── [Retake 50%] [Lanjut 50%] ────────────────────────────────────────
      return Row(
        children: [
          Expanded(
            child: _SecondaryButton(
              label: 'Retake',
              onTap: _onRetake,
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 8.w : 12.w),
          Expanded(
            child: _PrimaryButton(
              label: 'Lanjut',
              onTap: _onNext,
              isMobile: isMobile,
            ),
          ),
        ],
      );
    }

    // During countdown & capturing: spacer to keep layout stable
    return SizedBox(height: isMobile ? 40.h : 46.h);
  }
}

// ── Left Sidebar: Photo Strip Preview (tanpa card) ────────────────────────────

class _FrameStripPreview extends StatelessWidget {
  const _FrameStripPreview({
    required this.frame,
    required this.capturedPhotos,
    required this.currentPoseIndex,
    this.liveCameraPreview,
  });

  final FrameModel? frame;
  final List<XFile?> capturedPhotos;
  final int currentPoseIndex;
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

    // Tampilkan PhotoStripWidget langsung tanpa card/container wrapper
    return Center(
      child: PhotoStripWidget(
        photos: displayPhotos,
        frame: frame,
        activePoseIndex: currentPoseIndex,
        liveCameraPreview: liveCameraPreview,
      ),
    );
  }
}

// ── Clean Buttons ─────────────────────────────────────────────────────────────

/// 1 tombol toggle Mirror ↔ No Mirror
class _MirrorToggleButton extends StatelessWidget {
  const _MirrorToggleButton({
    required this.isMirrorEnabled,
    required this.onTap,
    required this.isMobile,
  });

  final bool isMirrorEnabled;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isMobile ? 40.h : 46.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isMirrorEnabled
              ? AppColors.darkBrown.withValues(alpha: 0.08)
              : AppColors.creamWhite,
          foregroundColor: AppColors.darkBrown,
          side: BorderSide(
            color: AppColors.darkBrown.withValues(alpha: 0.6),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.w : 12.w),
        ),
        child: Text(
          isMirrorEnabled ? 'Mirror' : 'No Mirror',
          style: GoogleFonts.montserrat(
            fontSize: isMobile ? 12.sp : 13.sp,
            fontWeight: isMirrorEnabled ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.darkBrown,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isMobile,
  });

  final String label;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isMobile ? 40.h : 46.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonBrown,
          foregroundColor: AppColors.creamWhite,
          elevation: 3,
          shadowColor: AppColors.darkBrown.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
            side: const BorderSide(color: AppColors.gold, width: 1.0),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.w : 12.w),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: isMobile ? 13.sp : 14.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.creamWhite,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
    required this.isMobile,
  });

  final String label;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isMobile ? 40.h : 46.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.creamWhite,
          foregroundColor: AppColors.darkBrown,
          side: const BorderSide(color: AppColors.darkBrown, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.w : 12.w),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: isMobile ? 12.5.sp : 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBrown,
          ),
        ),
      ),
    );
  }
}
