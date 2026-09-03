import 'dart:async';
import 'dart:ui' as ui;
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
import '../../../core/services/photo_upload_prep_service.dart';
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

/// Kualitas JPEG saat foto harus ditulis ulang (hanya terjadi bila mirror ON).
const int _kMasterJpegQuality = 93;

/// Ukuran gambar hasil pembacaan header JPEG.
class _JpegSize {
  const _JpegSize(this.width, this.height);
  final int width;
  final int height;
}

/// Baca dimensi JPEG dari penanda SOF, tanpa men-decode gambarnya.
///
/// Dipakai untuk log pada jalur bypass. Membaca beberapa puluh KB pertama saja,
/// jadi biayanya ~1 ms — jalur mirror OFF tetap praktis nol.
_JpegSize? _readJpegSizeFromHeader(Uint8List head) {
  if (head.length < 4 || head[0] != 0xFF || head[1] != 0xD8) return null;
  var i = 2;
  while (i + 9 < head.length) {
    if (head[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = head[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    final segLen = (head[i + 2] << 8) | head[i + 3];
    if (segLen < 2) return null;
    final isSof = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      final p = i + 4;
      if (p + 5 > head.length) return null;
      final h = (head[p + 1] << 8) | head[p + 2];
      final w = (head[p + 3] << 8) | head[p + 4];
      return (w > 0 && h > 0) ? _JpegSize(w, h) : null;
    }
    if (marker == 0xDA) return null;
    i += 2 + segLen;
  }
  return null;
}

class _EncodeRgbaArgs {
  const _EncodeRgbaArgs({
    required this.rgba,
    required this.width,
    required this.height,
    required this.decodeMs,
  });
  final Uint8List rgba;
  final int width;
  final int height;
  final int decodeMs;
}

class _PreparedPhoto {
  const _PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
    required this.decodeMs,
    required this.flipMs,
    required this.encodeMs,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final int decodeMs;
  final int flipMs;
  final int encodeMs;
}

/// Tahap kedua jalur mirror ON: piksel mentah -> flip -> JPEG.
///
/// Decode sudah dikerjakan codec bawaan, jadi di sini TIDAK ada decode dan
/// TIDAK ada resize. Dijalankan di isolate terpisah supaya encode tidak
/// membekukan UI.
_PreparedPhoto? _flipAndEncodeRgba(_EncodeRgbaArgs a) {
  var image = img.Image.fromBytes(
    width: a.width,
    height: a.height,
    bytes: a.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  final swFlip = Stopwatch()..start();
  image = img.flipHorizontal(image);
  swFlip.stop();

  final swEncode = Stopwatch()..start();
  final out = img.encodeJpg(image, quality: _kMasterJpegQuality);
  swEncode.stop();

  return _PreparedPhoto(
    bytes: out,
    width: image.width,
    height: image.height,
    decodeMs: a.decodeMs,
    flipMs: swFlip.elapsedMilliseconds,
    encodeMs: swEncode.elapsedMilliseconds,
  );
}

/// Jalur cadangan Dart murni: decode -> flip -> encode. Tanpa resize.
/// Hanya dipakai bila codec bawaan gagal.
_PreparedPhoto? _flipAndEncodeDart(Uint8List bytes) {
  final swDecode = Stopwatch()..start();
  var image = img.decodeImage(bytes);
  swDecode.stop();
  if (image == null) return null;

  final swFlip = Stopwatch()..start();
  image = img.flipHorizontal(image);
  swFlip.stop();

  final swEncode = Stopwatch()..start();
  final out = img.encodeJpg(image, quality: _kMasterJpegQuality);
  swEncode.stop();

  return _PreparedPhoto(
    bytes: out,
    width: image.width,
    height: image.height,
    decodeMs: swDecode.elapsedMilliseconds,
    flipMs: swFlip.elapsedMilliseconds,
    encodeMs: swEncode.elapsedMilliseconds,
  );
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

  /// Teks status saat penyiapan kamera, ditampilkan di kotak viewfinder.
  String? _prepMessage;

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

    // Pulihkan pilihan mirror dari sesi.
    //
    // `_isMirrorEnabled` sebelumnya hanya state lokal layar: ditulis ke
    // session provider tapi tidak pernah dibaca kembali. Begitu State layar
    // ini dibuat ulang - pindah pose, kembali dari halaman lain - nilainya
    // kembali ke false meskipun tamu sudah menekan Mirror. Preview dan berkas
    // hasil sama-sama mengikuti nilai yang sudah ter-reset itu, sehingga
    // terlihat seperti "tombol mirror tidak berfungsi".
    _isMirrorEnabled = ref.read(sessionNotifierProvider).isMirrorEnabled;
    debugPrint('🪞 [CameraScreen] Mirror dipulihkan dari sesi: $_isMirrorEnabled');

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
    // Sesi PTP sengaja TIDAK diputus di sini. Membukanya lagi mengharuskan
    // stream HDMI dihentikan sementara, jadi memutusnya tiap dispose berarti
    // kedipan preview di setiap perpindahan layar.
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
        setState(() => _captureMode = mode);

        // Handshake PTP DULU, sebelum stream HDMI dinyalakan.
        //
        // Ini satu-satunya jendela di mana bus USB cukup lengang: capture card
        // dan kamera berbagi hub yang sama, dan selama capture card streaming
        // 1080p30, pembacaan balasan OpenSession selalu gagal (endpoint IN
        // ter-stall, respons 0x0000, lalu semua perintah ditolak 0x2003).
        //
        // Sesi PTP dipakai ulang dan tidak diputus saat dispose, jadi
        // penyiapan ini hanya terjadi sekali per aplikasi berjalan —
        // kunjungan berikutnya ke halaman kamera langsung menampilkan preview.
        if (!capture.ptpReady) {
          setState(() => _prepMessage = 'Menyiapkan kamera Sony...');
          // WAJIB lewat ensureShutterPath(), bukan memanggil
          // prepareShutterPathWithUvcPaused() langsung. Panggilan langsung
          // melewati penjaga single-flight, sehingga jaring pengaman di
          // _onUvcOpenResult bisa menyalakan handshake KEDUA yang berjalan
          // bersamaan di perangkat USB yang sama — keduanya lalu saling
          // menutup koneksi dan sama-sama gagal.
          await capture.ensureShutterPath();
          if (!mounted) return;
          setState(() => _prepMessage = null);
        }

        setState(() => _showUvcView = true);
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

      // Jaring pengaman: normalnya handshake PTP sudah selesai di
      // _initExternalCamera() SEBELUM preview dinyalakan. Kalau ternyata
      // belum (mis. sesi putus di tengah jalan), coba sekali lagi dengan
      // menjeda stream — tanpa menunggu, jadi preview tetap bisa dipakai.
      if (!PhotoboothCaptureService.instance.ptpReady) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            PhotoboothCaptureService.instance.startShutterPathWithUvcPaused();
          }
        });
      }
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

  /// True bila preview sudah benar-benar menampilkan gambar.
  bool get _isPreviewLive {
    if (_showUvcView || _isUvcReady) return UvcCameraService.instance.isOpen;
    return _isCameraReady && _cameraController != null;
  }

  /// Tunggu preview hidup sebelum hitungan mundur dimulai.
  ///
  /// Tanpa ini, angka mundur sudah berjalan sementara layar masih gelap —
  /// tamu kehilangan beberapa detik untuk bersiap.
  Future<void> _waitForPreview({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isPreviewLive) return;
    // Mode Sony tanpa capture card: preview memang tidak akan pernah hidup.
    // Menunggunya hanya menahan hitungan mundur tanpa hasil.
    final capture = PhotoboothCaptureService.instance;
    if (capture.mode == CaptureMode.windowsSony && !capture.uvcReady) return;
    final deadline = DateTime.now().add(timeout);
    while (mounted && !_isPreviewLive && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _startCountdown() async {
    ref.read(sessionNotifierProvider.notifier).setMirror(_isMirrorEnabled);

    // Tampilkan layar tunggu, bukan hitungan mundur, selama kamera belum siap.
    if (!_isPreviewLive) {
      setState(() => _step = _CaptureStep.initialPreview);
      await _waitForPreview();
      if (!mounted) return;
    }

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
        // Kunci fokus satu hitungan sebelum jepret. AF butuh ~0,8 detik; kalau
        // baru dimulai saat hitungan habis, rana terasa telat sedetik.
        // Dijalankan tanpa ditunggu supaya hitungan mundur tetap presisi.
        if (_countdownValue == 2) {
          unawaited(PhotoboothCaptureService.instance.prefocus());
        }
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

  /// Satu-satunya tempat nilai mirror berubah.
  ///
  /// Menulis ke sesi sekaligus, supaya pilihan tamu bertahan saat layar ini
  /// dibuat ulang untuk pose berikutnya.
  void _toggleMirror() {
    final next = !_isMirrorEnabled;
    setState(() => _isMirrorEnabled = next);
    ref.read(sessionNotifierProvider.notifier).setMirror(next);
    debugPrint('🪞 [CameraScreen] Tombol mirror ditekan → $next');
  }

  Future<void> _capturePhoto() async {
    setState(() => _step = _CaptureStep.capturing);
    if (!mounted) return;

    try {
      // Pastikan handshake PTP (yang jalan paralel sejak halaman dibuka) sudah
      // selesai sebelum menjepret. Biasanya sudah, karena hitungan mundur
      // memberi waktu beberapa detik.
      await PhotoboothCaptureService.instance.awaitShutterPath();

      final outcome = await PhotoboothCaptureService.instance.capture();
      if (!mounted) return;

      if (outcome.success && outcome.file != null) {
        debugPrint('📸 [CameraScreen] Foto dari ${outcome.source.name}');
        final processedFile = await _processCapturedPhoto(
          XFile(outcome.file!.path),
          _isMirrorEnabled,
          source: outcome.source,
        );
        if (!mounted) return;
        setState(() {
          _lastCaptured = processedFile;
          _step = _CaptureStep.result;
        });
        return;
      }

      // Mode hybrid / ptpOnly: kamera Sony adalah SATU-SATUNYA sumber yang sah.
      // Jangan turun diam-diam ke kamera tablet — itu menghasilkan foto yang
      // bukan dari Sony sama sekali, dan tamu tidak akan tahu.
      final mode = PhotoboothCaptureService.instance.mode;
      if (mode == CaptureMode.hybrid ||
          mode == CaptureMode.ptpOnly ||
          mode == CaptureMode.windowsSony) {
        debugPrint('❌ [CameraScreen] Capture GAGAL (${outcome.message}). '
            'Mode $mode tidak mengizinkan fallback — silakan ulangi jepretan.');
        ErrorLogger.instance.logCameraError(
          message: 'Capture Sony PTP gagal: ${outcome.message}',
        );
        setState(() {
          _lastCaptured = null;
          _step = _CaptureStep.result;
        });
        return;
      }

      debugPrint('⚠️ [CameraScreen] Kamera eksternal tidak tersedia '
          '(${outcome.message}) — memakai kamera tablet (mode $mode).');
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
    final processedFile = await _processCapturedPhoto(
      rawFile,
      _isMirrorEnabled,
      source: CaptureSource.tablet,
    );
    if (!mounted) return;
    setState(() {
      _lastCaptured = processedFile;
      _step = _CaptureStep.result;
    });
  }

  /// [source] WAJIB menyebut dari mana foto ini benar-benar berasal.
  ///
  /// Dulu ini disimpulkan dari `_cameraController.description.lensDirection`,
  /// dan itu salah pada jalur Sony di Windows: controller yang ada adalah
  /// CAPTURE CARD, dan Windows melaporkannya sebagai `front`. Fotonya sendiri
  /// datang dari Sony, bukan dari capture card. Akibatnya logika cermin
  /// terbalik — mirror mati justru dicermin (sekaligus menanggung decode 24 MP
  /// yang lambat), mirror nyala justru tidak.
  /// Decode memakai codec bawaan Flutter (Skia/libjpeg-turbo), lalu flip dan
  /// encode sekali di isolate terpisah.
  ///
  /// Tanpa resize dan tanpa target resolusi: kamera sudah diset ke Image Size M
  /// (4240x2832), jadi ukuran itulah yang dipertahankan apa adanya.
  ///
  /// Mengembalikan null bila jalur ini tidak bisa dipakai, sehingga pemanggil
  /// jatuh ke jalur Dart murni — optimasi tidak boleh membuat foto gagal.
  Future<_PreparedPhoto?> _flipViaNativeCodec(Uint8List raw) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      final swDecode = Stopwatch()..start();
      buffer = await ui.ImmutableBuffer.fromUint8List(raw);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      swDecode.stop();

      final rgba = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;

      return await compute(
        _flipAndEncodeRgba,
        _EncodeRgbaArgs(
          rgba: rgba.buffer.asUint8List(),
          width: decoded.width,
          height: decoded.height,
          decodeMs: swDecode.elapsedMilliseconds,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [ImageProcessor] Codec bawaan gagal ($e) — '
          'memakai jalur Dart murni');
      return null;
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// [source] WAJIB menyebut dari mana foto ini benar-benar berasal.
  Future<XFile> _processCapturedPhoto(
    XFile rawFile,
    bool isMirrored, {
    required CaptureSource source,
  }) async {
    // SATU SUMBER KEBENARAN: status cermin yang dipakai preview.
    //
    // Preview me-render `Transform.flip(flipX: _isMirrorEnabled)`, jadi berkas
    // hasil harus mengikuti nilai yang sama persis. Satu pengecualian yang
    // memang benar secara fisik: sensor kamera DEPAN tablet sudah menghasilkan
    // gambar ter-cermin, sehingga nilainya dibalik. Kamera eksternal — Sony
    // maupun frame HDMI — tidak, jadi mengikuti langsung.
    final isFrontCam = source == CaptureSource.tablet &&
        _cameraController?.description.lensDirection ==
            CameraLensDirection.front;
    final needsFlip = isFrontCam ? !isMirrored : isMirrored;

    final swTotal = Stopwatch()..start();
    final file = dart_io.File(rawFile.path);

    // ── MIRROR OFF: JPEG asli dari Sony dipakai apa adanya ──────────────────
    //
    // Tidak ada decode, tidak ada encode, tidak ada penulisan berkas. Foto dari
    // kamera sudah tepat seperti yang harus dicetak; membongkar lalu menyusunnya
    // kembali hanya membuang ~2,5 detik DAN menurunkan mutu, karena setiap
    // siklus decode-encode JPEG itu lossy.
    if (!needsFlip) {
      _JpegSize? size;
      try {
        // Baca kepala berkas saja untuk keperluan log — bukan seluruh gambar.
        //
        // 256 KB, bukan 64 KB: JPEG dari Sony menyimpan thumbnail EXIF dan
        // MakerNote yang besar sebelum penanda SOF, sehingga 64 KB pertama
        // belum memuat dimensinya. Dan seluruh potongan stream digabung —
        // `.first` hanya memberi potongan pertama, yang ukurannya tidak dijamin.
        final head = await file
            .openRead(0, 262144)
            .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d));
        size = _readJpegSizeFromHeader(head.takeBytes());
      } catch (_) {}
      final dim = size == null ? 'asli' : '${size.width}x${size.height}';
      debugPrint('🖼️ [ImageProcessor] $dim → $dim | mirror=false | '
          'decode=0ms flip=0ms encode=0ms '
          'total=${swTotal.elapsedMilliseconds}ms [bypass original JPEG]');
      return rawFile;
    }

    // ── MIRROR ON: satu kali decode → flip → satu kali encode ───────────────
    try {
      final raw = await file.readAsBytes();
      final srcSize = _readJpegSizeFromHeader(raw);

      var prepared = await _flipViaNativeCodec(raw);
      final usedFallback = prepared == null;
      prepared ??= await compute(_flipAndEncodeDart, raw);
      if (prepared == null) {
        debugPrint('⚠️ [ImageProcessor] Gagal memproses — memakai berkas asli '
            '(hasil TIDAK ter-cermin)');
        return rawFile;
      }

      // Hasil ditulis ke folder sementara supaya folder Pictures tetap berisi
      // hanya foto asli dari sensor.
      final workDir = dart_io.Directory(
        '${dart_io.Directory.systemTemp.path}'
        '${dart_io.Platform.pathSeparator}snaptechbooth_work',
      );
      if (!workDir.existsSync()) workDir.createSync(recursive: true);
      final name = rawFile.path.split(dart_io.Platform.pathSeparator).last;
      final outFile = dart_io.File(
        '${workDir.path}${dart_io.Platform.pathSeparator}$name',
      );
      await outFile.writeAsBytes(prepared.bytes, flush: true);
      await FileImage(outFile).evict();

      final src = srcSize == null
          ? '${prepared.width}x${prepared.height}'
          : '${srcSize.width}x${srcSize.height}';
      debugPrint('🖼️ [ImageProcessor] $src → '
          '${prepared.width}x${prepared.height} | mirror=true | '
          'decode=${prepared.decodeMs}ms flip=${prepared.flipMs}ms '
          'encode=${prepared.encodeMs}ms total=${swTotal.elapsedMilliseconds}ms'
          '${usedFallback ? " [dart murni]" : " [codec bawaan]"}');

      return XFile(outFile.path);
    } catch (e) {
      debugPrint('⚠️ [ImageProcessor] Penyiapan foto gagal: $e');
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

    // Mulai memperkecil foto SEKARANG, selagi tamu bersiap untuk pose
    // berikutnya. Saat halaman hasil dibuka, byte-nya sudah siap sehingga QR
    // muncul jauh lebih cepat.
    if (_lastCaptured != null) {
      PhotoUploadPrepService.instance.warm(_lastCaptured!.path);
    }

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
    // PENTING: SELALU kembalikan _buildCameraViewfinder(), termasuk pada tahap
    // `result`. Dulu tahap result mengembalikan subtree lain
    // (_buildPhotoResultDisplay), sehingga UvcPreview ter-unmount → detachView()
    // → kamera native DITUTUP. Menekan "Lanjut" berarti membuka ulang kamera
    // (400ms PlatformView + ~1-3 detik openUVCCamera + 350ms tirai), dan itulah
    // kenapa layar gelap sementara hitungan mundur sudah berjalan.
    //
    // Sekarang hasil foto hanya ditumpuk sebagai overlay di atas preview yang
    // tetap hidup, jadi kamera cukup dibuka SEKALI per sesi.
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
        return _buildCameraViewfinder(
          showOverlay: false,
          overlayChild: _buildCapturedPhotoOverlay(),
        );
    }
  }

  /// Hasil jepretan, ditumpuk menutupi preview (bukan menggantikannya).
  Widget _buildCapturedPhotoOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.darkCoffee,
        child: _lastCaptured != null
            ? Image.file(
                // Berkas ini SUDAH ter-cermin bila memang perlu, jadi jangan
                // dicermin lagi di layar — itu akan membatalkannya.
                dart_io.File(_lastCaptured!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // Batasi decode: foto 24 MP dari Sony tidak perlu di-decode
                // penuh hanya untuk pratinjau.
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
    ).animate().fadeIn(duration: 200.ms);
  }

  /// Rasio kotak viewfinder.
  ///
  /// PENTING: jangan ambil rasio dari `_cameraController` saja — di mode
  /// HDMI/UVC controller itu NULL, dan dulu nilainya jatuh ke default
  /// 720/1280 (potret 9:16). Itulah yang membuat panel kamera berdiri tegak
  /// dan feed 16:9 hanya muncul sebagai pita tipis di tengah.
  double get _viewfinderAspectRatio {
    if (_showUvcView || _isUvcReady) return _uvcPreviewWidth / _uvcPreviewHeight;

    // Selama deteksi perangkat belum selesai, _cameraController masih null.
    // Default landscape membuat panel benar sejak frame pertama, tanpa
    // "melompat" dari tegak ke mendatar saat HDMI terbuka.
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_prepMessage != null)
                          SizedBox(
                            width: 28.r,
                            height: 28.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.gold,
                            ),
                          )
                        else
                          Icon(
                            Icons.photo_camera_rounded,
                            size: 42.sp,
                            color: AppColors.paper.withValues(alpha: 0.35),
                          ),
                        if (_prepMessage != null) ...[
                          SizedBox(height: 10.h),
                          Text(
                            _prepMessage!,
                            style: TextStyle(
                              color: AppColors.paper.withValues(alpha: 0.75),
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              if (showOverlay)
                Container(color: Colors.black.withValues(alpha: 0.55)),
              if (overlayChild != null) overlayChild,
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
              onTap: _toggleMirror,
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
