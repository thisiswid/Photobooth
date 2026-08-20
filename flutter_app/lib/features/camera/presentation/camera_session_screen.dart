import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/session_header.dart';

/// Tahap yang ditampilkan di panel kamera sebelah kanan.
enum _CaptureStage { idle, countdown, capturing, result }

/// Gaya bingkai preview kecil di sidebar "Pilih Frame".
enum _FrameStyle { classic, arch, dotted, filmstrip }

class _FrameOption {
  const _FrameOption({required this.id, required this.label, required this.style});
  final String id;
  final String label;
  final _FrameStyle style;
}

const _frameOptions = [
  _FrameOption(id: 'classic-1', label: 'Classic', style: _FrameStyle.classic),
  _FrameOption(id: 'fakultas', label: 'Fakultas Kopi', style: _FrameStyle.filmstrip),
  _FrameOption(id: 'arch-1', label: 'Arch', style: _FrameStyle.arch),
  _FrameOption(id: 'dotted-1', label: 'Dotted', style: _FrameStyle.dotted),
  _FrameOption(id: 'classic-2', label: 'Warm', style: _FrameStyle.classic),
  _FrameOption(id: 'arch-2', label: 'Sage', style: _FrameStyle.arch),
  _FrameOption(id: 'polaroid', label: 'Polaroid', style: _FrameStyle.classic),
  _FrameOption(id: 'filmstrip-2', label: 'Filmstrip', style: _FrameStyle.filmstrip),
];

/// Screen 5 — Pilih Frame & Sesi Foto (kamera + countdown + retake/next),
/// matching UI referensi `Detail_halaman_foto.png`.
///
/// Satu screen ini menangani beberapa "step" desain sekaligus lewat
/// [_CaptureStage]: idle (preview + tombol mulai) → countdown → capturing
/// → result (retake/next). Untuk sesi dengan lebih dari satu pose, tab
/// "POSE 1 / POSE 2" tampil di atas dan alur berulang sampai pose terakhir.
class CameraSessionScreen extends ConsumerStatefulWidget {
  const CameraSessionScreen({super.key, this.totalPoses = 2});

  final int totalPoses;

  @override
  ConsumerState<CameraSessionScreen> createState() => _CameraSessionScreenState();
}

class _CameraSessionScreenState extends ConsumerState<CameraSessionScreen> {
  static const _countdownSeconds = 5;

  CameraController? _cameraController;
  bool _isCameraReady = false;

  String _selectedFrameId = _frameOptions.first.id;
  bool _mirrorEnabled = true;
  _CaptureStage _stage = _CaptureStage.idle;
  int _currentPose = 0;
  int _countdown = _countdownSeconds;
  final List<XFile> _capturedPhotos = [];
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

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
    } catch (_) {
      // Kamera tidak tersedia — panel kamera akan menampilkan fallback.
    }
  }

  // ── Capture flow ──────────────────────────────────────────────────────

  void _setMirror(bool value) {
    setState(() => _mirrorEnabled = value);
  }

  void _startCapture() {
    if (_stage != _CaptureStage.idle) return;
    setState(() {
      _stage = _CaptureStage.countdown;
      _countdown = _countdownSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _takePhoto();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _takePhoto() async {
    setState(() => _stage = _CaptureStage.capturing);

    XFile? photo;
    try {
      photo = await _cameraController?.takePicture();
    } catch (_) {
      // Biarkan null — result stage tetap tampil dengan placeholder.
    }

    // Jeda singkat agar transisi "sedang diambil" terasa natural.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      if (photo != null) _capturedPhotos.add(photo);
      _stage = _CaptureStage.result;
    });
  }

  void _retake() {
    if (_capturedPhotos.length > _currentPose) {
      _capturedPhotos.removeLast();
    }
    setState(() => _stage = _CaptureStage.idle);
  }

  void _next() {
    final isLastPose = _currentPose >= widget.totalPoses - 1;
    if (!isLastPose) {
      setState(() {
        _currentPose++;
        _stage = _CaptureStage.idle;
      });
      return;
    }

    // TODO: kirim `_capturedPhotos` ke sessionNotifierProvider begitu
    // method penyimpanan foto per-pose tersedia di provider.
    context.go(AppRoutes.filter);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final remaining = sessionState.remainingTime;
    final minutes = (remaining.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final timerText = minutes == '00' && seconds == '00' ? '09:45' : '$minutes:$seconds';

    return PhotoboothLayout(
      header: SessionHeader(timerText: timerText),
      child: Column(
        children: [
          if (widget.totalPoses > 1) ...[
            SizedBox(height: 4.h),
            _PoseTabs(total: widget.totalPoses, current: _currentPose),
          ],
          SizedBox(height: 12.h),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FrameSidebar(
                    selectedId: _selectedFrameId,
                    enabled: _stage == _CaptureStage.idle || _stage == _CaptureStage.result,
                    onSelect: (id) => setState(() => _selectedFrameId = id),
                  ),
                  SizedBox(width: 24.w),
                  Expanded(child: _CameraPanel(state: this)),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          const _SessionHint(),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

// ── Sidebar: Pilih Frame ────────────────────────────────────────────────────

class _FrameSidebar extends StatelessWidget {
  const _FrameSidebar({
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
  });

  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168.w,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.parchmentLight,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.borderWarm, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PILIH FRAME',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.coffeeBrown,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: GridView.builder(
                itemCount: _frameOptions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.h,
                  crossAxisSpacing: 8.w,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (_, i) {
                  final frame = _frameOptions[i];
                  return _FrameThumbnail(
                    frame: frame,
                    isSelected: frame.id == selectedId,
                    onTap: enabled ? () => onSelect(frame.id) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameThumbnail extends StatelessWidget {
  const _FrameThumbnail({
    required this.frame,
    required this.isSelected,
    required this.onTap,
  });

  final _FrameOption frame;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppColors.coffeeBrown : AppColors.borderWarm;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Stack(
          children: [
            Positioned.fill(
              child: switch (frame.style) {
                _FrameStyle.classic => _ClassicFrame(borderColor: borderColor),
                _FrameStyle.arch => _ArchFrame(borderColor: borderColor),
                _FrameStyle.dotted => _DottedFrame(borderColor: borderColor),
                _FrameStyle.filmstrip => _FilmstripFrame(borderColor: borderColor),
              },
            ),
            if (isSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.coffeeBrown,
                  ),
                  child: Icon(Icons.check_rounded, size: 10.sp, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassicFrame extends StatelessWidget {
  const _ClassicFrame({required this.borderColor});
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}

class _ArchFrame extends StatelessWidget {
  const _ArchFrame({required this.borderColor});
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22.r),
          topRight: Radius.circular(22.r),
          bottomLeft: Radius.circular(4.r),
          bottomRight: Radius.circular(4.r),
        ),
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}

class _DottedFrame extends StatelessWidget {
  const _DottedFrame({required this.borderColor});
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: borderColor),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    );
  }
}

class _FilmstripFrame extends StatelessWidget {
  const _FilmstripFrame({required this.borderColor});
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          6,
          (_) => Container(width: 6.w, height: 6.w, color: AppColors.parchment),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

// ── Panel Kamera (kanan) ────────────────────────────────────────────────────

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({required this.state});
  final _CameraSessionScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.parchmentLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
      ),
      child: Column(
        children: [
          Expanded(child: _buildStage(context)),
          SizedBox(height: 16.h),
          _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (state._stage) {
      case _CaptureStage.idle:
      case _CaptureStage.countdown:
        return _PreviewArea(
          controller: state._cameraController,
          isReady: state._isCameraReady,
          mirror: state._mirrorEnabled,
          countdown: state._stage == _CaptureStage.countdown ? state._countdown : null,
        );
      case _CaptureStage.capturing:
        return const _CapturingArea();
      case _CaptureStage.result:
        return _ResultArea(frameId: state._selectedFrameId);
    }
  }

  Widget _buildControls(BuildContext context) {
    if (state._stage == _CaptureStage.result) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54.h,
              child: ResponsiveButton(
                label: 'RETAKE',
                icon: Icons.refresh_rounded,
                variant: ButtonVariant.outlined,
                onPressed: state._retake,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: SizedBox(
              height: 54.h,
              child: ResponsiveButton(
                label: 'NEXT',
                icon: Icons.arrow_forward_rounded,
                onPressed: state._next,
              ),
            ),
          ),
        ],
      );
    }

    final controlsEnabled = state._stage == _CaptureStage.idle;

    return Row(
      children: [
        Text(
          'Cermin',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.coffeeBrown,
          ),
        ),
        SizedBox(width: 12.w),
        _MirrorToggle(
          enabled: controlsEnabled,
          isMirrored: state._mirrorEnabled,
          onChanged: (value) => state._setMirror(value),
        ),
        const Spacer(),
        SizedBox(
          width: 200.w,
          height: 54.h,
          child: ResponsiveButton(
            label: 'MULAI FOTO',
            icon: Icons.camera_alt_rounded,
            onPressed: controlsEnabled ? state._startCapture : null,
          ),
        ),
      ],
    );
  }
}

class _MirrorToggle extends StatelessWidget {
  const _MirrorToggle({
    required this.enabled,
    required this.isMirrored,
    required this.onChanged,
  });

  final bool enabled;
  final bool isMirrored;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            label: 'MIRROR',
            icon: Icons.flip_rounded,
            isActive: isMirrored,
            onTap: enabled ? () => onChanged(true) : null,
          ),
          _ToggleOption(
            label: 'NO MIRROR',
            icon: Icons.crop_original_rounded,
            isActive: !isMirrored,
            onTap: enabled ? () => onChanged(false) : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? AppColors.coffeeBrown : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: isActive ? AppColors.white : AppColors.textSecondary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stage: Live Preview + Countdown overlay ─────────────────────────────────

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({
    required this.controller,
    required this.isReady,
    required this.mirror,
    required this.countdown,
  });

  final CameraController? controller;
  final bool isReady;
  final bool mirror;
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isReady && controller != null)
            Transform.flip(
              flipX: mirror,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.previewSize?.height ?? 1,
                  height: controller!.value.previewSize?.width ?? 1,
                  child: CameraPreview(controller!),
                ),
              ),
            )
          else
            Container(color: AppColors.parchmentDark),
          if (countdown != null)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96.r,
                      height: 96.r,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 96.r,
                            height: 96.r,
                            child: CircularProgressIndicator(
                              value: countdown! / 5,
                              strokeWidth: 4,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation(AppColors.goldAccent),
                            ),
                          ),
                          Text(
                            '$countdown',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'BERSIAP YA!',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stage: Sedang mengambil foto ────────────────────────────────────────────

class _CapturingArea extends StatelessWidget {
  const _CapturingArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coffeeBrown,
              ),
              child: Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 32.sp),
            ),
            SizedBox(height: 18.h),
            Text(
              'FOTO SEDANG DIAMBIL',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.coffeeBrown,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Mohon diam sebentar ya',
              style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stage: Hasil foto ───────────────────────────────────────────────────────

class _ResultArea extends StatelessWidget {
  const _ResultArea({required this.frameId});
  final String frameId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 0.72,
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: AppColors.parchmentDark,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.coffeeBrown, width: 2),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E8DA),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: Icon(Icons.face_rounded, size: 80.sp, color: AppColors.coffeeBrown),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Fakultas Kopi',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.coffeeBrown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pose Tabs (untuk sesi multi-pose) ───────────────────────────────────────

class _PoseTabs extends StatelessWidget {
  const _PoseTabs({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(width: 28.w, height: 1, color: AppColors.borderWarm);
        }
        final poseIndex = i ~/ 2;
        final isDone = poseIndex < current;
        final isActive = poseIndex == current;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: isActive || isDone ? AppColors.coffeeBrown : AppColors.parchmentLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isActive || isDone ? AppColors.coffeeBrown : AppColors.borderWarm,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone) ...[
                Icon(Icons.check_rounded, size: 12.sp, color: AppColors.white),
                SizedBox(width: 4.w),
              ],
              Text(
                'POSE ${poseIndex + 1}',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isActive || isDone ? AppColors.white : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Hint bawah: durasi sesi & batas retake ──────────────────────────────────

class _SessionHint extends StatelessWidget {
  const _SessionHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        '1 sesi foto: 5 menit\nMaksimal 2 kali retake per pose',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
