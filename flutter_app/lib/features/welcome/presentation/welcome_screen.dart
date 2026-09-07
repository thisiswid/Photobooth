import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/sony_ptp_camera_service.dart';
import '../../../core/services/uvc_camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/booth_material.dart';
import '../../../shared/widgets/logo_emblem.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../../../shared/widgets/unified_camera_preview.dart';
import '../../../shared/widgets/uvc_preview.dart';
import '../../provisioning/providers/tenant_provider.dart';

/// Layar Sambutan — material kamar gelap.
///
/// Kamera langsung sebagai latar penuh: tamu melihat dirinya sendiri sebelum
/// menyentuh apa pun. Itu undangan yang paling jujur untuk sebuah photobooth,
/// dan bagian itu memang sudah benar sejak awal.
///
/// Yang dirombak cuma lapisan di atasnya:
///   - botanical empat sudut dihapus
///   - denyut berulang pada tombol dihapus (pola game mobile)
///   - overshoot easeOutBack pada lambang dihapus
///   - emas diganti warna spot tenant
///   - satu tanda pencetak di kaki layar sebagai satu-satunya ornamen
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _material = BoothMaterial.bench;

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isUvcReady = false;
  bool _showUvcView = false; // render UVCCameraView sebelum open() dipanggil
  bool _isNavigating = false; // Flag untuk mencegah race condition & double tap

  // Gestur darurat operator: ketuk lambang 5x dalam 2 detik.
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Tunggu frame pertama selesai render agar PlatformView UVCCameraView
    // sudah ada di layar sebelum openUVCCamera() dipanggil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isNavigating) _initCamera();
    });
  }

  @override
  void dispose() {
    _isNavigating = true;
    try {
      _cameraController?.dispose();
    } catch (e) {
      debugPrint('⚠️ [WelcomeScreen] Error disposing cameraController: $e');
    }
    _cameraController = null;
    super.dispose();
  }

  /// Menavigasi ke layar berikutnya dengan aman.
  /// Melepaskan view kamera terlebih dahulu agar native surface (JNI libuvc / Camera2)
  /// tidak mengalami crash SIGSEGV atau platform view collision saat berganti rute.
  Future<void> _handleStartSession() async {
    if (_isNavigating || !mounted) return;
    setState(() => _isNavigating = true);

    try {
      // Lepas kamera internal jika aktif
      final cam = _cameraController;
      _cameraController = null;
      if (cam != null) {
        try {
          await cam.dispose();
        } catch (e) {
          debugPrint('⚠️ [WelcomeScreen] Cam dispose error during navigation: $e');
        }
      }

      // Sembunyikan UVC view sebelum pindah rute agar PlatformView tidak dihancurkan
      // secara mendadak saat streaming frame sedang berlangsung
      if (_showUvcView || _isUvcReady) {
        if (mounted) {
          setState(() {
            _showUvcView = false;
            _isUvcReady = false;
            _isCameraReady = false;
          });
        }
        // Jeda singkat 100ms untuk memastikan engine Flutter dan Android Surface melepaskan tekstur
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('⚠️ [WelcomeScreen] Error in _handleStartSession: $e');
    }

    if (!mounted) return;
    context.go(AppRoutes.tutorial);
  }

  // ── Kamera ────────────────────────────────────────────────────────────────

  /// Callback dari [UvcPreview] setelah percobaan membuka kamera HDMI selesai.
  Future<void> _onUvcOpenResult(bool opened) async {
    if (!mounted || _isNavigating) return;
    debugPrint('🔍 [WelcomeScreen] uvcOpened=$opened '
        'lastError=${UvcCameraService.instance.lastError}');
    if (opened) {
      setState(() {
        _isUvcReady = true;
        _isCameraReady = true;
      });
      return;
    }
    debugPrint('⚠️ [WelcomeScreen] UVC gagal — fallback ke Camera2');
    setState(() {
      _showUvcView = false;
      _isUvcReady = false;
    });
    await _initTabletCamera();
  }

  Future<void> _initCamera() async {
    if (_isNavigating || !mounted) return;
    final status = await Permission.camera.request();
    if (!mounted || _isNavigating) return;

    try {
      final sonyStatus = await SonyPtpCameraService.getStatus();
      if (!mounted || _isNavigating) return;
      debugPrint('🔍 [WelcomeScreen] uvcDetected=${sonyStatus.uvcDetected} '
          'ptpDetected=${sonyStatus.ptpDetected}');

      // Cukup render UvcPreview — widget itu yang mendaftarkan generasi view
      // dan memanggil open() pada saat yang tepat. Hasilnya masuk lewat
      // _onUvcOpenResult. (Factory native hanya menyimpan satu referensi view,
      // jadi open dari luar widget bisa mengenai view yang salah.)
      if (sonyStatus.uvcDetected) {
        if (mounted && !_isNavigating) {
          setState(() => _showUvcView = true);
        }
        return;
      }

      if (!status.isGranted) {
        debugPrint('❌ [WelcomeScreen] Camera permission not granted');
        return;
      }

      await _initTabletCamera();
    } catch (e) {
      debugPrint('❌ [WelcomeScreen] _initCamera error: $e');
    }
  }

  /// Fallback kamera tablet (Camera2) — dipakai bila capture card HDMI tidak
  /// terdeteksi atau gagal dibuka.
  Future<void> _initTabletCamera() async {
    if (_isNavigating || !mounted) return;
    try {
      debugPrint('📷 [WelcomeScreen] Inisialisasi Camera2 fallback...');
      final oldController = _cameraController;
      _cameraController = null;
      if (mounted) setState(() => _isCameraReady = false);
      try {
        await oldController?.dispose();
      } catch (_) {}

      if (!mounted || _isNavigating) return;

      final controller = await CameraService.createController(
        resolution: ResolutionPreset.medium,
      );
      if (!mounted || _isNavigating) {
        try {
          await controller?.dispose();
        } catch (_) {}
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
      debugPrint('❌ [WelcomeScreen] _initTabletCamera error: $e');
    }
  }

  // ── Akses operator ────────────────────────────────────────────────────────

  void _onLogoSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
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

  /// Membuka Hidden Device Settings dengan verifikasi PIN pengelola.
  ///
  /// CATATAN: versi sebelumnya menerima PIN KOSONG sebagai sah
  /// (`... == '1234' || ....isEmpty`), jadi siapa pun yang menemukan gestur
  /// lima ketukan tinggal menekan tombol untuk masuk ke panel operator. Jalan
  /// pintas itu dihapus.
  Future<void> _promptSettingsPin() async {
    final pinController = TextEditingController();

    final authorized = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.benchRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          side: const BorderSide(
            color: AppColors.benchLine,
            width: AppGeometry.hairline,
          ),
        ),
        title: Text(
          'AKSES PENGELOLA',
          style: AppFonts.ui(
            color: AppColors.light,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan PIN untuk membuka panel perangkat.',
              style: AppFonts.display(
                color: AppColors.light60,
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppGeometry.s16.h),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 4,
              textAlign: TextAlign.center,
              onSubmitted: (val) {
                if (val.trim() == '1234') {
                  Navigator.of(ctx).pop(true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.inkOxide,
                      content: Text(
                        'PIN salah.',
                        style: AppFonts.display(
                          color: AppColors.paperBright,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  );
                }
              },
              style: AppFonts.ui(
                color: AppColors.light,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.bench,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                  borderSide: const BorderSide(color: AppColors.benchLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                  borderSide: const BorderSide(color: AppColors.benchLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                  borderSide: const BorderSide(
                    color: AppColors.light,
                    width: AppGeometry.ruleSelected,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'BATAL',
              style: AppFonts.ui(
                color: AppColors.light60,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text.trim() == '1234') {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.inkOxide,
                    content: Text(
                      'PIN salah.',
                      style: AppFonts.display(
                        color: AppColors.paperBright,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'BUKA',
              style: AppFonts.ui(
                color: AppColors.light,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );

    if (authorized == true && mounted) {
      // Lepaskan controller kamera welcome screen terlebih dahulu agar tidak
      // memicu konflik driver / hardware lock pada Windows MediaFoundation
      // saat panel Settings membuka preview kamera.
      final cam = _cameraController;
      _cameraController = null;
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _showUvcView = false;
          _isUvcReady = false;
        });
      }
      try {
        await cam?.dispose();
      } catch (e) {
        debugPrint('⚠️ [WelcomeScreen] Cam dispose before settings error: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        context.go(AppRoutes.deviceSettings);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final isCompact = isMobile || isPortrait;
    final tenant = ref.watch(tenantNotifierProvider).valueOrNull;
    final screen = tenant?.screens['welcome'];

    final cafeName = tenant?.cafe.name ?? AppConstants.defaultCafeBrandName;
    final title = ((screen?['title'] as String?) ?? cafeName).toUpperCase();
    final buttonLabel = (screen?['button_text'] as String?) ?? 'Mulai sesi foto';
    final spot = tenant?.cafe.theme.primaryColor ?? AppColors.spot;

    return Scaffold(
      backgroundColor: AppColors.bench,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Kamera langsung sebagai latar ──────────────────────────────
          if (_isUvcReady || _showUvcView)
            UvcPreview(onOpenResult: _onUvcOpenResult)
          else if (_isCameraReady)
            UnifiedCameraPreview(
              isUvcMode: false,
              cameraController: _cameraController,
            )
          else
            const ColoredBox(color: AppColors.bench),

          // ── Selubung Kamar Gelap Tipis (Transparan agar kamera terlihat jelas) ──
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8A17120F),
                  Color(0x3317120F),
                  Color(0xAA17120F),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Overlay Jendela Bidik Kamera Studio (Full Screen) ───────────
          _CameraViewfinderOverlay(isCompact: isCompact),

          SafeArea(
            child: Column(
              children: [
                // ── Area Atas: Penanda Status Kamera (hanya indikator titik) ──
                Padding(
                  padding: EdgeInsets.all(AppGeometry.s16.r),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusDot(online: _isCameraReady),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),

                // ── Konten Utama (Lambang, Nama, CTA) ─────────────────────
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppGeometry.s24.w,
                        vertical: AppGeometry.s8.h,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _onLogoSecretTap,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: isMobile ? 104.r : 138.r,
                              height: isMobile ? 104.r : 138.r,
                              padding: EdgeInsets.all(AppGeometry.s16.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.paperBright,
                                border: Border.all(
                                  color: spot,
                                  width: AppGeometry.ruleSelected,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: LogoEmblem(
                                size: (isMobile ? 104.r : 138.r) - AppGeometry.s32.r,
                                showRing: false,
                              ),
                            ),
                          ),

                          SizedBox(height: AppGeometry.s24.h),

                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppFonts.display(
                              color: AppColors.light,
                              fontSize: (isMobile ? 32 : 46).sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              height: 1.08,
                            ),
                          ),

                          SizedBox(height: isCompact ? AppGeometry.s24.h : AppGeometry.s32.h),

                          // ── Tombol Utama Mulai Sesi Foto (CTA) ───────────
                          Container(
                            width: isMobile ? 270.w : 360.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                              boxShadow: [
                                BoxShadow(
                                  color: spot.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ResponsiveButton(
                              label: buttonLabel,
                              material: _material,
                              isLoading: _isNavigating,
                              onPressed: _handleStartSession,
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                                end: 1.025,
                                duration: 1400.ms,
                                curve: Curves.easeInOut,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Tanda pencetak di kaki layar ─────────────────────────
                Padding(
                  padding: EdgeInsets.only(bottom: AppGeometry.s16.h),
                  child: const _PrintersMark(),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppMotion.reveal);
  }
}

/// Penanda status perangkat untuk operator
/// Penanda status perangkat untuk operator (titik halus tanpa teks)
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.inkGreenLit : AppColors.spotLit;
    return Container(
      width: 8.r,
      height: 8.r,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}



/// Jendela Bidik Kamera Studio (Viewfinder Overlay)
class _CameraViewfinderOverlay extends StatelessWidget {
  const _CameraViewfinderOverlay({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 4 Sudut Bracket Fokus
          _CornerBrackets(
            margin: isCompact ? 16.r : 28.r,
            size: isCompact ? 24.r : 36.r,
          ),

          // Crosshair Pusat Kamera
          Center(
            child: SizedBox(
              width: 32.r,
              height: 32.r,
              child: CustomPaint(
                painter: _CenterCrosshairPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets({required this.margin, required this.size});

  final double margin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: margin,
          left: margin,
          child: _Bracket(isTop: true, isLeft: true, size: size),
        ),
        Positioned(
          top: margin,
          right: margin,
          child: _Bracket(isTop: true, isLeft: false, size: size),
        ),
        Positioned(
          bottom: margin,
          left: margin,
          child: _Bracket(isTop: false, isLeft: true, size: size),
        ),
        Positioned(
          bottom: margin,
          right: margin,
          child: _Bracket(isTop: false, isLeft: false, size: size),
        ),
      ],
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.isTop, required this.isLeft, required this.size});
  final bool isTop;
  final bool isLeft;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BracketPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.isTop, required this.isLeft});
  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.light30.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.light30.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 6.0;

    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
    canvas.drawCircle(Offset(cx, cy), 12, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



class _PrintersMark extends StatelessWidget {
  const _PrintersMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 14.w, height: 1, color: AppColors.light30),
        SizedBox(width: AppGeometry.s8.w),
        Text(
          'POWERED BY SNAPTECH',
          style: AppFonts.ui(
            color: AppColors.light30,
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        SizedBox(width: AppGeometry.s8.w),
        Container(width: 14.w, height: 1, color: AppColors.light30),
      ],
    );
  }
}
