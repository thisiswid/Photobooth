import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/corner_decorations.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../../provisioning/providers/tenant_provider.dart';

import '../../../core/services/sony_ptp_camera_service.dart';
import '../../../core/services/uvc_camera_service.dart';
import '../../../shared/widgets/unified_camera_preview.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';

/// Welcome Screen — Retro-Modern Artisan Studio Grand Entrance.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isUvcReady = false;
  bool _showUvcView = false; // render UVCCameraView sebelum open() dipanggil

  // Kontrol visibilitas tombol setting (Disembunyikan 100% dari customer)
  final bool _showSettingsIcon = false;

  // Emergency gesture (tap 5x pada logo)
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Tunggu frame pertama selesai render agar PlatformView UVCCameraView
    // sudah ada di layar sebelum openUVCCamera() dipanggil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    try {
      // 1. Cek apakah UVC device terhubung
      final sonyStatus = await SonyPtpCameraService.getStatus();
      debugPrint('🔍 [WelcomeScreen] sonyStatus: isDetected=${sonyStatus.isDetected} isUvc=${sonyStatus.isUvc} hasPermission=${sonyStatus.hasPermission}');

      if ((sonyStatus.isDetected || sonyStatus.isUvc) && sonyStatus.hasPermission) {
        setState(() => _showUvcView = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        final uvcOpened = await UvcCameraService.instance.open();
        debugPrint('🔍 [WelcomeScreen] uvcOpened=$uvcOpened lastError=${UvcCameraService.instance.lastError}');
        if (uvcOpened && mounted) {
          setState(() {
            _isUvcReady = true;
            _isCameraReady = true;
          });
          return;
        }
        if (mounted) {
          debugPrint('⚠️ [WelcomeScreen] UVC open gagal — fallback ke Camera2');
          setState(() => _showUvcView = false);
        }
      }

      if (!status.isGranted) {
        debugPrint('❌ [WelcomeScreen] Camera permission not granted');
        return;
      }

      debugPrint('📷 [WelcomeScreen] Inisialisasi Camera2 fallback...');
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
        debugPrint('✅ [WelcomeScreen] Camera2 ready');
        setState(() {
          _cameraController = controller;
          _isCameraReady = true;
        });
      } else {
        debugPrint('❌ [WelcomeScreen] Camera2 createController returned null');
      }
    } catch (e) {
      debugPrint('❌ [WelcomeScreen] _initCamera error: $e');
    }
  }

  /// Membuka Hidden Device Settings dengan verifikasi PIN pengelola (default: 1234)
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
              'Masukkan PIN Administrator untuk mengakses Hidden Device Settings:',
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
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
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
            child: const Text('Buka Device Settings'),
          ),
        ],
      ),
    );

    if (isAuthorized == true && mounted) {
      context.go(AppRoutes.deviceSettings);
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

    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName = (tenantConfig?.cafe.name ?? AppConstants.defaultCafeBrandName).toUpperCase();
    final welcomeTitle = ((tenantConfig?.screens['welcome']?['title'] as String?) ?? cafeName).toUpperCase();
    final welcomeSubtitle = ((tenantConfig?.screens['welcome']?['description'] as String?) ?? 'SELF-SERVICE PHOTOBOOTH').toUpperCase();
    final buttonLabel = ((tenantConfig?.screens['welcome']?['button_text'] as String?) ?? 'MULAI SESI FOTO').toUpperCase();
    final logoUrl = tenantConfig?.cafe.logoUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Live camera BG ─────────────────────────────────────────────
          // UVCCameraView hanya di-render setelah _showUvcView = true
          // (set oleh _initCamera sebelum openUVCCamera dipanggil)
          if (_isUvcReady || _showUvcView)
            UVCCameraView(
              cameraController: UvcCameraService.instance.controller,
              width: double.infinity,
              height: double.infinity,
            )
          else if (_isCameraReady)
            UnifiedCameraPreview(
              isUvcMode: false,
              cameraController: _isCameraReady ? _cameraController : null,
            )
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

          // ── Header Bar (Setting Icon & Status) ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16.w : 24.w,
                  vertical: 12.h,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status dot
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7.r,
                            height: 7.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'ONLINE',
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Kiosk Settings Button (Disembunyikan jika dimatikan via Admin)
                    if (_showSettingsIcon)
                      IconButton(
                        onPressed: _promptSettingsPin,
                        icon: Icon(
                          Icons.settings_outlined,
                          color: AppColors.creamWhite.withValues(alpha: 0.85),
                          size: isMobile ? 22.sp : 26.sp,
                        ),
                      ),
                  ],
                ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20.w : 40.w,
                  vertical: 16.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            color: (tenantConfig?.cafe.theme.primaryColor ?? AppColors.gold).withValues(alpha: 0.75),
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
                              color: tenantConfig?.cafe.theme.primaryColor ?? AppColors.gold,
                              width: 1.5,
                            ),
                          ),
                          padding: EdgeInsets.all(isMobile ? 12.r : 18.r),
                          child: (logoUrl != null && logoUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: logoUrl,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Image.asset(
                                    AppConstants.defaultLogoAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      AppConstants.logoSnaptechAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.camera_alt_rounded,
                                        color: AppColors.darkBrown,
                                        size: isMobile ? 60.r : 90.r,
                                      ),
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  AppConstants.defaultLogoAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    AppConstants.logoSnaptechAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.camera_alt_rounded,
                                      color: AppColors.darkBrown,
                                      size: isMobile ? 60.r : 90.r,
                                    ),
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

                      // Dynamic Cafe / Welcome Title
                      Text(
                        welcomeTitle,
                        textAlign: TextAlign.center,
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

                      // Dynamic Subtitle with Accent Lines
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isMobile ? 16.w : 32.w,
                            height: 1.2,
                            color: (tenantConfig?.cafe.theme.primaryColor ?? AppColors.gold).withValues(alpha: 0.8),
                          ),
                          SizedBox(width: isMobile ? 6.w : 10.w),
                          Text(
                            welcomeSubtitle,
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
                            color: (tenantConfig?.cafe.theme.primaryColor ?? AppColors.gold).withValues(alpha: 0.8),
                          ),
                        ],
                      ).animate().fadeIn(delay: 450.ms),

                      SizedBox(height: isMobile ? 24.h : 36.h),

                      // Grand CTA Button — Dynamic Label
                      SizedBox(
                        width: isMobile ? (isPortrait ? 260.w : 220.w) : 320.w,
                        height: isMobile ? 54.h : 68.h,
                        child: ResponsiveButton(
                          label: buttonLabel,
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
        ],
      ),
    );
  }
}
