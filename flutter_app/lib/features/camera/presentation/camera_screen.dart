import 'dart:async';
import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
import '../../../core/services/photobooth_capture_service.dart';
import '../../../core/services/uvc_camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/frame/domain/models/frame_model.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../../../shared/widgets/uvc_preview.dart';

/// Dijalankan di isolate terpisah oleh `compute()` — JANGAN panggil langsung
/// dari isolate UI: decode/encode JPEG 24 MP butuh beberapa detik.
Uint8List? _flipJpegBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return img.encodeJpg(img.flipHorizontal(decoded), quality: 95);
}

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

  // ── Kamera eksternal (HDMI capture card + Sony PTP) ────────────────────────
  CaptureMode _captureMode = CaptureMode.tabletOnly;
  /// True bila preview HDMI (UVC) sudah terbuka untuk view di layar ini.
  bool _isUvcReady = false;
  /// True begitu kita memutuskan me-render UvcPreview (sebelum open selesai).
  bool _showUvcView = false;

  /// Resolusi HDMI yang diminta — dipakai juga untuk rasio kotak viewfinder
  /// agar panel dan gambar benar-benar sebangun (tanpa letterbox).
  static const double _uvcPreviewWidth = 1920;
  static const double _uvcPreviewHeight = 1080;

  // ── Flow state ────────────────────────────────────────────────────────────
  _CaptureStep _step = _CaptureStep.initialPreview;
  int _countdownValue = _countdownSeconds;
  Timer? _countdownTimer;

  // ── Poses state ───────────────────────────────────────────────────────────
  int _currentPose = 0;
  XFile? _lastCaptured;
  List<XFile?> _capturedPhotos = [];
  bool _isMirrorEnabled = false;

  @override
  void initState() {
    super.initState();
    _initExternalCamera();
    // CATATAN: dulu di sini ada Timer.periodic(1 detik) yang memanggil
    // setState kosong. Itu me-rebuild SELURUH pohon widget — termasuk
    // PlatformView kamera — setiap detik, yang terlihat sebagai kedipan
    // "garis-garis warna" (pola no-signal capture card) tiap satu detik.
    // Tidak ada widget di layar ini yang bergantung pada waktu, jadi timer
    // tersebut dihapus. Countdown punya timer sendiri (_countdownTimer).
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    // Hanya lepaskan sesi PTP. Kamera UVC dikelola oleh UvcPreview — menutupnya
    // di sini akan mematikan preview halaman berikutnya.
    PhotoboothCaptureService.instance.releasePtp();
    super.dispose();
  }

  // ── Init kamera eksternal (HDMI preview + shutter PTP) ────────────────────

  /// Alur yang sama dengan layar welcome & sesi foto:
  ///  1. deteksi kabel mana yang terpasang → tentukan mode
  ///  2. siapkan jalur shutter PTP (kalau kabel C-to-C ada & PC Remote aktif)
  ///  3. render UvcPreview untuk jalur preview HDMI; widget itu yang membuka
  ///     kamera untuk generasi view-nya sendiri
  ///  4. baru fallback ke kamera tablet
  Future<void> _initExternalCamera() async {
    try {
      final capture = PhotoboothCaptureService.instance;
      final mode = await capture.detectMode();
      if (!mounted) return;

      if (capture.usesUvcPreview) {
        // Tampilkan preview LEBIH DULU. UvcPreview yang membuka kamera untuk
        // generasi view-nya sendiri.
        setState(() {
          _captureMode = mode;
          _showUvcView = true;
        });
        // Handshake PTP jalan PARALEL di latar belakang — jangan di-await di
        // sini. Menunggunya (2-6 detik) membuat layar gelap sampai hitungan
        // mundur sudah berjalan. Hasilnya ditunggu tepat sebelum menjepret.
        capture.startShutterPath();
        return;
      }

      setState(() => _captureMode = mode);
      capture.startShutterPath();
      await _initCamera();
    } catch (e) {
      debugPrint('⚠️ [CameraScreen] _initExternalCamera error: $e');
      await _initCamera();
    }
  }

  /// Callback dari [UvcPreview] setelah percobaan membuka kamera HDMI selesai.
  Future<void> _onUvcOpenResult(bool opened) async {
    if (!mounted) return;
    debugPrint('🔍 [CameraScreen] uvcOpened=$opened '
        'lastError=${UvcCameraService.instance.lastError}');

    PhotoboothCaptureService.instance.markPreviewReady(opened);

    if (opened) {
      setState(() {
        _isUvcReady = true;
        _isCameraReady = true;
      });
      return;
    }

    setState(() {
      _showUvcView = false;
      _isUvcReady = false;
    });
    await _initCamera();
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

  /// Live preview: stream HDMI bila tersedia, kalau tidak kamera tablet.
  ///
  /// CATATAN: hanya boleh ada SATU UvcPreview yang ter-mount pada satu waktu
  /// (factory native plugin cuma menyimpan satu referensi view). Karena itu
  /// widget ini mengembalikan UvcPreview hanya untuk panel utama; strip kecil
  /// memakai placeholder saat mode HDMI aktif.
  Widget? _buildLivePreview() {
    if (_showUvcView || _isUvcReady) {
      // Panel utama sudah merender UvcPreview — jangan mount yang kedua.
      return null;
    }
    if (!_isCameraReady || _cameraController == null) return null;
    return Transform.flip(
      flipX: _isMirrorEnabled,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.width ?? 1280,
          height: _cameraController!.value.previewSize?.height ?? 720,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    setState(() => _step = _CaptureStep.capturing);
    if (!mounted) return;

    try {
      // Pastikan handshake PTP (yang jalan paralel sejak halaman dibuka) sudah
      // selesai sebelum menjepret. Biasanya sudah, karena hitungan mundur
      // memberi waktu beberapa detik.
      await PhotoboothCaptureService.instance.awaitShutterPath();

      // Jalur eksternal: shutter PTP (resolusi penuh) → frame HDMI → tablet.
      // Semua langkah punya timeout, jadi UI tidak pernah menggantung.
      final outcome = await PhotoboothCaptureService.instance.capture();
      if (!mounted) return;

      if (outcome.success && outcome.file != null) {
        debugPrint('📸 [CameraScreen] Foto dari ${outcome.source.name}');
        final processedFile = await _processCapturedPhoto(
          XFile(outcome.file!.path),
          _isMirrorEnabled,
        );
        if (!mounted) return;
        setState(() {
          _lastCaptured = processedFile;
          _step = _CaptureStep.result;
        });
        return;
      }

      debugPrint('⚠️ [CameraScreen] Kamera eksternal gagal (${outcome.message}) '
          '— fallback ke kamera tablet');
      await _captureFromTabCamera();
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

  /// Capture menggunakan kamera bawaan tablet (fallback dari Sony).
  Future<void> _captureFromTabCamera() async {
    if (_cameraController == null || !_isCameraReady) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _lastCaptured = null;
        _step = _CaptureStep.result;
      });
      return;
    }
    final rawFile =
        await _cameraController!.takePicture().timeout(const Duration(seconds: 10));
    if (!mounted) return;
    final processedFile = await _processCapturedPhoto(rawFile, _isMirrorEnabled);
    if (!mounted) return;
    setState(() {
      _lastCaptured = processedFile;
      _step = _CaptureStep.result;
    });
  }

  Future<XFile> _processCapturedPhoto(XFile rawFile, bool isMirrored) async {
    // Kamera tablet depan sudah menghasilkan gambar ter-cermin dari sensor;
    // kamera eksternal (PTP / HDMI) tidak.
    final isFrontCam =
        _cameraController?.description.lensDirection == CameraLensDirection.front;
    final needsFlip = isFrontCam ? !isMirrored : isMirrored;

    // JALUR CEPAT: tidak perlu di-flip → jangan decode apa pun.
    //
    // PENTING: sejak shutter PTP aktif, file dari Sony ZV-E10 berukuran
    // 6000x4000 (24 MP). Decode + encode ulang gambar sebesar itu di isolate
    // UI memakan beberapa detik dan langsung memicu ANR
    // ("SnapTechBooth isn't responding"). Karena itu kerja berat dipindah ke
    // isolate lain lewat compute(), dan dilewati sepenuhnya bila tidak perlu.
    if (!needsFlip) return rawFile;

    try {
      final bytes = await rawFile.readAsBytes();
      final newBytes = await compute(_flipJpegBytes, bytes);
      if (newBytes == null) return rawFile;
      final processedFile = dart_io.File(rawFile.path);
      await processedFile.writeAsBytes(newBytes, flush: true);
      return XFile(processedFile.path);
    } catch (e) {
      debugPrint('⚠️ [CameraScreen] _processCapturedPhoto gagal: $e');
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
                  liveCameraPreview:
                      (_step == _CaptureStep.initialPreview || _step == _CaptureStep.countdown)
                          ? _buildLivePreview()
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

  /// Rasio kotak viewfinder.
  ///
  /// PENTING: sebelumnya rasio selalu diambil dari `_cameraController`, padahal
  /// di mode HDMI/UVC controller itu NULL — sehingga jatuh ke default
  /// 720/1280 (potret 9:16). Itulah kenapa panel kamera berdiri tegak dan
  /// feed 16:9 hanya muncul sebagai pita tipis di tengah.
  ///
  /// Di mode eksternal kita pakai rasio asli HDMI (16:9) supaya kotaknya
  /// benar-benar mendatar dan gambar mengisi penuh tanpa letterbox.
  double get _viewfinderAspectRatio {
    if (_showUvcView || _isUvcReady) return _uvcPreviewWidth / _uvcPreviewHeight;

    // Selama deteksi perangkat belum selesai, _cameraController masih null.
    // Dulu di sini dipakai default 720/1280 (potret) sehingga panel sempat
    // berdiri tegak lalu "melompat" jadi mendatar begitu HDMI terbuka.
    // Default landscape membuat panel benar sejak frame pertama.
    final size = _cameraController?.value.previewSize;
    if (size == null) return _uvcPreviewWidth / _uvcPreviewHeight;
    return size.width / size.height;
  }

  Widget _buildCameraViewfinder({required bool showOverlay, Widget? overlayChild}) {
    return AspectRatio(
      aspectRatio: _viewfinderAspectRatio,
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
              if (_showUvcView || _isUvcReady)
                UvcPreview(
                  mirror: _isMirrorEnabled,
                  onOpenResult: _onUvcOpenResult,
                  previewWidth: _uvcPreviewWidth.toInt(),
                  previewHeight: _uvcPreviewHeight.toInt(),
                )
              else if (_isCameraReady && _cameraController != null)
                Center(
                  child: Transform.flip(
                    flipX: _isMirrorEnabled,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.width ?? 1280,
                        height: _cameraController!.value.previewSize?.height ?? 720,
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
              // Badge diagnostik jalur kamera (untuk operator)
              Positioned(
                top: 8.h,
                left: 8.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    PhotoboothCaptureService.describeMode(_captureMode),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
    // Samakan bentuk dengan viewfinder supaya panel tidak "melompat" ukuran
    // saat berpindah dari live preview ke hasil foto.
    return AspectRatio(
      aspectRatio: _viewfinderAspectRatio,
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
        child: _lastCaptured != null
            ? Image.file(
                dart_io.File(_lastCaptured!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // Batasi decode: tanpa ini foto 24 MP dari Sony di-decode
                // penuh ke memori hanya untuk thumbnail preview.
                cacheWidth: 1080,
                filterQuality: FilterQuality.medium,
              )
            : Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48.sp,
                  color: AppColors.paper.withValues(alpha: 0.4),
                ),
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
