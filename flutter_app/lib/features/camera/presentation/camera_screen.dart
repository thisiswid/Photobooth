import 'dart:async';
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
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

// ── Frame data ────────────────────────────────────────────────────────────────

class _FrameData {
  const _FrameData({required this.id, required this.name, required this.color});
  final String id;
  final String name;
  final Color color;
}

const _mockFrames = [
  _FrameData(id: 'classic_gold',  name: 'Classic Gold',  color: Color(0xFFC89B5B)),
  _FrameData(id: 'coffee_brown',  name: 'Coffee Brown',  color: Color(0xFF5C3A21)),
  _FrameData(id: 'midnight',      name: 'Midnight',      color: Color(0xFF1A1A2E)),
  _FrameData(id: 'rose_gold',     name: 'Rose Gold',     color: Color(0xFFB76E79)),
  _FrameData(id: 'forest',        name: 'Forest',        color: Color(0xFF2D6A4F)),
  _FrameData(id: 'minimal',       name: 'Minimal White', color: Color(0xFFF8F8F8)),
];

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
  String _selectedFrameId = _mockFrames.first.id;

  // ── Current pose ──────────────────────────────────────────────────────────
  int _currentPose = 0;     // 0-based
  int _retakeCount = 0;
  XFile? _lastCaptured;
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
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Simulasi capture — di produksi pakai _cameraController!.takePicture()
    setState(() {
      _lastCaptured = null; // placeholder
      _step = _CaptureStep.result;
    });
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

    // Simpan foto ke session
    notifier.addPhoto(PhotoModel(
      id: _uuid.v4(),
      sessionId: sessionId,
      fileUrl: 'assets/mock/photo_placeholder.png',
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

    return PopScope(
      canPop: false,
      child: PhotoboothLayout(
        showDecorations: _step != _CaptureStep.countdown,
        header: CustomerHeader(
          trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
        ),
        child: Column(
          children: [
            // ── Pose indicator ──────────────────────────────────────────
            _PoseIndicator(current: _currentPose, total: totalPoses),

            SizedBox(height: 8.h),

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
          selectedFrameId: _selectedFrameId,
          isMirrorEnabled: _isMirrorEnabled,
          retakeCount: _retakeCount,
          maxRetake: _maxRetake,
          onFrameSelected: (id) => setState(() => _selectedFrameId = id),
          onMirrorToggle: () => setState(() => _isMirrorEnabled = !_isMirrorEnabled),
          onStartPhoto: _startCountdown,
        );
      case _CaptureStep.countdown:
        return _StepCountdown(
          cameraController: _isCameraReady ? _cameraController : null,
          countdown: _countdownValue,
          isMirrorEnabled: _isMirrorEnabled,
        );
      case _CaptureStep.capturing:
        return const _StepCapturing();
      case _CaptureStep.result:
        return _StepResult(
          capturedFile: _lastCaptured,
          selectedFrameId: _selectedFrameId,
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == current ? 32.w : 12.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.darkBrown : AppColors.borderWarm,
              borderRadius: BorderRadius.circular(4.r),
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
    'Pilih Frame', 'Countdown', 'Foto Diambil', 'Hasil Foto',
  ];

  @override
  Widget build(BuildContext context) {
    final stepIndex = _CaptureStep.values.indexOf(step);
    return Container(
      height: 36.h,
      color: AppColors.creamWhite.withValues(alpha: 0.8),
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
                    : isActive ? AppColors.lightBrown
                    : AppColors.borderWarm,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Text(
                  _labels[e.key],
                  style: TextStyle(
                    fontSize: 9.sp, fontWeight: FontWeight.w600,
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

// ── Step 1: Frame & Preview ───────────────────────────────────────────────────

class _StepFrameAndPreview extends StatelessWidget {
  const _StepFrameAndPreview({
    required this.cameraController,
    required this.selectedFrameId,
    required this.isMirrorEnabled,
    required this.retakeCount,
    required this.maxRetake,
    required this.onFrameSelected,
    required this.onMirrorToggle,
    required this.onStartPhoto,
  });

  final CameraController? cameraController;
  final String selectedFrameId;
  final bool isMirrorEnabled;
  final int retakeCount;
  final int maxRetake;
  final ValueChanged<String> onFrameSelected;
  final VoidCallback onMirrorToggle;
  final VoidCallback onStartPhoto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Kiri: Frame list ──────────────────────────────────────────
        SizedBox(
          width: 160.w,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 4.h),
                child: Text('Pilih Frame', style: AppTextStyles.titleSmall),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  itemCount: _mockFrames.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6.h),
                  itemBuilder: (_, i) => _FrameListTile(
                    frame: _mockFrames[i],
                    isSelected: _mockFrames[i].id == selectedFrameId,
                    onTap: () => onFrameSelected(_mockFrames[i].id),
                  ),
                ),
              ),
              // Retake info
              Container(
                margin: EdgeInsets.all(8.r),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: retakeCount >= maxRetake
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.creamWhite,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.borderWarm),
                ),
                child: Text(
                  'Retake: $retakeCount/$maxRetake',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: retakeCount >= maxRetake ? AppColors.error : AppColors.brown,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // ── Tengah: Camera preview ─────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: cameraController != null
                            ? Transform(
                                alignment: Alignment.center,
                                transform: isMirrorEnabled
                                    ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                                    : Matrix4.identity(),
                                child: CameraPreview(cameraController!),
                              )
                            : Container(
                                color: Colors.black,
                                child: Center(
                                  child: Icon(Icons.camera_alt_rounded,
                                      color: Colors.white38, size: 64.sp),
                                ),
                              ),
                      ),
                      // Mirror / No Mirror buttons
                      Positioned(
                        bottom: 12.h, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _MirrorButton(
                              label: 'Mirror',
                              isActive: isMirrorEnabled,
                              onTap: isMirrorEnabled ? null : onMirrorToggle,
                            ),
                            SizedBox(width: 8.w),
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
                SizedBox(height: 12.h),
                // Tombol Mulai Foto
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ResponsiveButton(
                    label: 'MULAI FOTO',
                    icon: Icons.camera_alt_rounded,
                    onPressed: onStartPhoto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FrameListTile extends StatelessWidget {
  const _FrameListTile({required this.frame, required this.isSelected, required this.onTap});
  final _FrameData frame;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBrown : AppColors.creamWhite,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.darkBrown : AppColors.borderWarm,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18.r, height: 18.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: frame.color),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(frame.name,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) Icon(Icons.check, color: AppColors.creamWhite, size: 14.sp),
          ],
        ),
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.darkBrown
              : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isActive ? AppColors.darkBrown : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12.sp, fontWeight: FontWeight.w600,
            color: isActive ? AppColors.creamWhite : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Countdown ─────────────────────────────────────────────────────────

class _StepCountdown extends StatelessWidget {
  const _StepCountdown({required this.cameraController, required this.countdown,
      required this.isMirrorEnabled});
  final CameraController? cameraController;
  final int countdown;
  final bool isMirrorEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera gelap
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cameraController != null)
                  Transform(
                    alignment: Alignment.center,
                    transform: isMirrorEnabled
                        ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                        : Matrix4.identity(),
                    child: CameraPreview(cameraController!),
                  )
                else
                  Container(color: Colors.black),
                // Dark overlay
                Container(color: Colors.black.withValues(alpha: 0.55)),
              ],
            ),
          ),
          // "BERSIAP YA!" di tengah
          Center(
            child: Text(
              'BERSIAP YA!',
              style: AppTextStyles.headlineLarge.copyWith(
                color: Colors.white,
                fontSize: 28.sp,
                letterSpacing: 4,
                shadows: [const Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
          // Countdown di kanan atas
          Positioned(
            top: 12,
            right: 12,
            child: Text(
              '$countdown',
              style: AppTextStyles.countdownNumber.copyWith(
                color: AppColors.creamWhite,
                fontSize: 80.sp,
                shadows: [const Shadow(color: Colors.black87, blurRadius: 20)],
              ),
            ).animate(key: ValueKey(countdown))
                .scale(begin: const Offset(1.3, 1.3), duration: 400.ms)
                .fadeIn(duration: 200.ms),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_rounded, size: 80.sp, color: AppColors.darkBrown)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1),
                  duration: 600.ms),
          SizedBox(height: 24.h),
          Text('FOTO SEDANG DIAMBIL',
            style: AppTextStyles.headlineMedium.copyWith(letterSpacing: 2),
          ).animate().fadeIn(duration: 400.ms),
          SizedBox(height: 8.h),
          Text('Mohon diam sebentar ya',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.brown),
          ).animate().fadeIn(delay: 200.ms),
          SizedBox(height: 32.h),
          SizedBox(
            width: 32.r, height: 32.r,
            child: CircularProgressIndicator(
              strokeWidth: 3, color: AppColors.darkBrown),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Result ────────────────────────────────────────────────────────────

class _StepResult extends StatelessWidget {
  const _StepResult({
    required this.capturedFile,
    required this.selectedFrameId,
    required this.retakeCount,
    required this.maxRetake,
    required this.onRetake,
    required this.onNext,
  });

  final XFile? capturedFile;
  final String selectedFrameId;
  final int retakeCount;
  final int maxRetake;
  final VoidCallback onRetake;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canRetake = retakeCount < maxRetake;
    final selectedFrame = _mockFrames.firstWhere(
      (f) => f.id == selectedFrameId, orElse: () => _mockFrames.first);

    return Row(
      children: [
        // ── Foto hasil ───────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                Text('Hasil Foto', style: AppTextStyles.titleMedium),
                SizedBox(height: 8.h),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedFrame.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: selectedFrame.color, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Center(
                        child: capturedFile != null
                            ? Image.asset('assets/mock/photo_placeholder.png', fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo, size: 80.sp, color: AppColors.lightBrown),
                                  SizedBox(height: 8.h),
                                  Text('Frame: ${selectedFrame.name}',
                                    style: AppTextStyles.bodySmall),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms).fadeIn(),

        // ── Tombol Retake / Next ─────────────────────────────────────
        SizedBox(
          width: 180.w,
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Retake info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.creamWhite,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.borderWarm),
                  ),
                  child: Text(
                    'Retake tersisa: ${maxRetake - retakeCount}/$maxRetake',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 24.h),
                // Retake button
                if (canRetake) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ResponsiveButton(
                      label: 'Retake', icon: Icons.refresh_rounded,
                      onPressed: onRetake, variant: ButtonVariant.outlined,
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
                // Next button
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ResponsiveButton(
                    label: 'Next', icon: Icons.arrow_forward_rounded,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideX(begin: 0.1, delay: 200.ms).fadeIn(delay: 200.ms),
      ],
    );
  }
}
