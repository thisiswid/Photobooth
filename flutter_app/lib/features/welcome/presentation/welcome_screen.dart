import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/corner_decorations.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Welcome Screen — NO header, logo besar tengah, live camera BG transparan.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!mounted || !status.isGranted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Live camera BG — tanpa overlay cream ───────────────────────
          if (_isCameraReady && _cameraController != null)
            _CameraBackground(controller: _cameraController!)
          else
            Container(color: Colors.black),

          // ── Subtle dark gradient di bagian bawah agar tombol terbaca ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 280.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // ── Botanical corner decorations ─────────────────────────────
          const CornerDecorations(opacity: 0.4),

          // ── Central branding ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo 2x lebih besar dari sebelumnya (300px), transparan
                  Image.asset(
                    'assets/images/logo.png',
                    width: 220.r,
                    height: 220.r,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_cafe_rounded,
                      color: Colors.white,
                      size: 220.r,
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 600.ms),

                  SizedBox(height: 20.h),

                  // FAKULTAS KOPI
                  Text(
                    'FAKULTAS KOPI',
                    style: AppTextStyles.brandNameLarge.copyWith(
                      color: Colors.white,
                      fontSize: 36.sp,
                      shadows: [
                        const Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  SizedBox(height: 4.h),

                  // PHOTObooth
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24.w, height: 1,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'PHOTObooth',
                        style: AppTextStyles.brandSubtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 24.w, height: 1,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ],
                  ).animate().fadeIn(delay: 450.ms),

                  const Spacer(flex: 2),

                  // Tombol MULAI — 1.5x lebih besar (84h vs 56h)
                  SizedBox(
                    width: 300.w,
                    height: 72.h,
                    child: ResponsiveButton(
                      label: 'MULAI',
                      icon: Icons.camera_alt_rounded,
                      onPressed: () => context.go(AppRoutes.tutorial),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, delay: 600.ms),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBackground extends StatelessWidget {
  const _CameraBackground({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    final aspectRatio = size != null ? size.width / size.height : 16 / 9;
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}
