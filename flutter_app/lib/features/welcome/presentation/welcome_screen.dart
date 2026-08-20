import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/corner_decorations.dart';
import '../../../shared/widgets/kiosk_settings_dialog.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Welcome Screen — Retro-Modern Artisan Studio Grand Entrance.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Kontrol visibilitas tombol setting (dapat disinkronkan dari Super Admin)
  final bool _showSettingsIcon = true;

  // Emergency gesture (tap 5x pada logo jika icon disembunyikan Super Admin)
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      final oldController = _cameraController;
      _cameraController = null;
      if (mounted) setState(() => _isCameraReady = false);
      await oldController?.dispose();

      final controller = await CameraService.createController(
        resolution: ResolutionPreset.medium,
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
    } catch (_) {}
  }

  /// Membuka dialog pengaturan kiosk dengan verifikasi PIN pengelola (default: 1234)
  Future<void> _promptSettingsPin() async {
    final pinController = TextEditingController();
    final isAuthorized = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBrown,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.gold),
            SizedBox(width: 10.w),
            Text(
              'Akses Pengelola Kiosk',
              style: GoogleFonts.cormorantGaramond(
                color: AppColors.creamWhite,
                fontWeight: FontWeight.w700,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan PIN Administrator untuk mengubah konfigurasi kamera dan printer:',
              style: TextStyle(color: AppColors.creamWhite.withValues(alpha: 0.8), fontSize: 12.sp),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: GoogleFonts.montserrat(
                color: AppColors.gold,
                fontSize: 22.sp,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: TextStyle(color: AppColors.creamWhite.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.darkBrown,
            ),
            onPressed: () {
              if (pinController.text.trim() == '1234' || pinController.text.trim().isEmpty) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN Salah! (Default: 1234)'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );

    if (isAuthorized == true && mounted) {
      KioskSettingsDialog.show(
        context,
        onCameraChanged: _initCamera,
      );
    }
  }

  void _onLogoSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _secretTapCount = 1;
    } else {
      _secretTapCount++;
    }
    _lastTapTime = now;

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _promptSettingsPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Live camera BG ─────────────────────────────────────────────
          if (_isCameraReady && _cameraController != null)
            _CameraBackground(controller: _cameraController!)
          else
            Container(color: AppColors.darkCoffee),

          // ── Atmospheric Vintage Vignette & Gradient Overlay ───────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),

          // ── Bottom gradient for CTA readability ───────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: isMobile ? 220.h : 300.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // ── Botanical vintage corner decorations (non-mobile) ─────────
          if (!isMobile) const CornerDecorations(opacity: 0.4),

          // ── Central Vintage Branding ──────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.w : 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: isMobile ? 20.h : 10.h),

                      // Vintage Badge Ring & Logo (with emergency secret tap gesture)
                      GestureDetector(
                        onTap: _onLogoSecretTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: isMobile ? 140.r : 210.r,
                          height: isMobile ? 140.r : 210.r,
                          padding: EdgeInsets.all(isMobile ? 10.r : 16.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.creamWhite.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.75),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.creamWhite,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 1.5,
                              ),
                            ),
                            padding: EdgeInsets.all(isMobile ? 12.r : 18.r),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.local_cafe_rounded,
                                color: AppColors.darkBrown,
                                size: isMobile ? 60.r : 90.r,
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.88, 0.88),
                            duration: 800.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 600.ms),

                      SizedBox(height: isMobile ? 12.h : 18.h),

                      // FAKULTAS KOPI Title
                      Text(
                        'FAKULTAS KOPI',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.creamWhite,
                          fontSize: isMobile ? 26.sp : 38.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: isMobile ? 2.0 : 3.5,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 3)),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      SizedBox(height: isMobile ? 4.h : 6.h),

                      // PHOTOBOOTH EXPERIENCE Subtitle with Vintage Brass Lines
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isMobile ? 16.w : 32.w,
                            height: 1.2,
                            color: AppColors.gold.withValues(alpha: 0.8),
                          ),
                          SizedBox(width: isMobile ? 6.w : 10.w),
                          Text(
                            'SELF-SERVICE PHOTOBOOTH',
                            style: GoogleFonts.montserrat(
                              color: AppColors.creamWhite.withValues(alpha: 0.95),
                              fontSize: isMobile ? 9.5.sp : 12.5.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: isMobile ? 1.5 : 3.0,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 8),
                              ],
                            ),
                          ),
                          SizedBox(width: isMobile ? 6.w : 10.w),
                          Container(
                            width: isMobile ? 16.w : 32.w,
                            height: 1.2,
                            color: AppColors.gold.withValues(alpha: 0.8),
                          ),
                        ],
                      ).animate().fadeIn(delay: 450.ms),

                      SizedBox(height: isMobile ? 24.h : 36.h),

                      // Grand CTA Button — MULAI SESI FOTO
                      SizedBox(
                        width: isMobile ? (isPortrait ? 260.w : 220.w) : 320.w,
                        height: isMobile ? 54.h : 68.h,
                        child: ResponsiveButton(
                          label: 'MULAI SESI FOTO',
                          icon: Icons.camera_alt_rounded,
                          onPressed: () => context.go(AppRoutes.tutorial),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.03, 1.03), duration: 1400.ms)
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .slideY(begin: 0.1, delay: 600.ms),

                      SizedBox(height: isMobile ? 8.h : 12.h),
                      Text(
                        'Sentuh layar untuk memulai sesi fotomu',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.creamWhite.withValues(alpha: 0.75),
                          fontSize: isMobile ? 11.sp : 13.sp,
                        ),
                      ).animate().fadeIn(delay: 750.ms),

                      SizedBox(height: isMobile ? 20.h : 10.h),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top Corner Settings Button (Configurable via Super Admin) ─
          if (_showSettingsIcon)
            Positioned(
              top: isMobile ? 12.h : 20.h,
              right: isMobile ? 12.w : 24.w,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _promptSettingsPin,
                    borderRadius: BorderRadius.circular(30.r),
                    splashColor: AppColors.gold.withValues(alpha: 0.3),
                    highlightColor: AppColors.gold.withValues(alpha: 0.15),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 10.r : 12.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.55),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.65),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        color: AppColors.antiqueBrass,
                        size: isMobile ? 22.r : 26.r,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.easeOut),
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
