import 'dart:async';
import 'dart:io' as dart_io;
import 'dart:typed_data' show BytesBuilder;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/services/photo_upload_prep_service.dart';
import '../../../core/services/photobooth_capture_service.dart';
import '../../../core/services/uvc_camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/booth_material.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../features/frame/domain/models/frame_model.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
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

/// Jalur mirror ON: 1x decode -> flip -> 1x encode. Tanpa resize.
///
/// Dijalankan di isolate terpisah supaya tidak membekukan UI.
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

/// Lama aba-aba "lihat ke lensa" sebelum angka mulai turun.
///
/// Sebelumnya hitungan langsung mulai dari 7 dan tamu menatap satu angka
/// besar selama tujuh detik tanpa tahu harus melihat ke mana. Studio
/// sungguhan memberi aba-aba dulu, baru menghitung.
const _cueDuration = Duration(milliseconds: 1600);

/// Nilai penanda tahap aba-aba di dalam [_CameraScreenState._countdown].
const _cueValue = -1;

/// Tampilkan preview kamera KECIL di dalam strip bingkai kiri.
///
/// Dimatikan karena mahal. `_buildLivePreview()` mengembalikan `CameraPreview`
/// kedua, sehingga DUA tekstur kamera 1080p dirender serentak sepanjang
/// `initialPreview` dan `countdown` — di atas viewfinder utama yang sudah
/// menampilkan gambar yang sama persis.
///
/// Terukur di perangkat: frame hitungan mundur tertunda 435-1460 ms, sehingga
/// angka 6 hanya sempat terlihat ~125 ms sebelum diganti 5. Tamu membacanya
/// sebagai "tahu-tahu sudah 3".
///
/// Penjagaan "jangan mount yang kedua" di `_buildLivePreview()` hanya berlaku
/// untuk jalur UVC Android; di Windows tidak pernah aktif.
///
/// Ubah ke `true` untuk mengembalikannya.
const bool _kStripLivePreview = false;

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
  /// Nilai hitungan mundur.
  ///
  /// Sengaja `ValueNotifier`, bukan state biasa. Dulu tiap detik memanggil
  /// `setState`, dan itu membangun ULANG SELURUH pohon layar — termasuk strip
  /// foto, semua `Image.file` pose sebelumnya, dan preview kamera. Tujuh kali
  /// per pose, makin berat tiap pose karena strip bertambah isi.
  ///
  int get _configuredCountdownSeconds {
    final tenant = ref.read(tenantNotifierProvider).valueOrNull;
    return tenant?.timers.cameraCountdownSeconds ?? tenant?.hardware.countdownSeconds ?? 5;
  }

  /// Sekarang hanya angka dan lingkaran progresnya yang dibangun ulang.
  late final ValueNotifier<int> _countdown = ValueNotifier<int>(_configuredCountdownSeconds);
  Timer? _countdownTimer;

  /// Penanda waktu untuk mengukur jeda antara tombol Lanjut ditekan dan
  /// hitungan mundur benar-benar TERLIHAT bergerak.
  Stopwatch? _perfWatch;

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

  bool _isNavigating = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdown.dispose();
    try {
      _cameraController?.dispose();
    } catch (e) {
      debugPrint('⚠️ [CameraScreen] error in dispose: $e');
    }
    _cameraController = null;
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
      await capture.detectMode();
      if (!mounted) return;

      if (capture.usesUvcPreview) {
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
    _perfWatch ??= Stopwatch()..start();
    debugPrint('⏱️ [Perf] _startCountdown masuk '
        '(+${_perfWatch?.elapsedMilliseconds ?? 0} ms)');
    ref.read(sessionNotifierProvider.notifier).setMirror(_isMirrorEnabled);

    // Tampilkan layar tunggu, bukan hitungan mundur, selama kamera belum siap.
    if (!_isPreviewLive) {
      debugPrint('⏱️ [Perf] Preview belum hidup — menunggu '
          '(+${_perfWatch?.elapsedMilliseconds ?? 0} ms)');
      setState(() => _step = _CaptureStep.initialPreview);
      await _waitForPreview();
      if (!mounted) return;
      debugPrint('⏱️ [Perf] Selesai menunggu preview '
          '(+${_perfWatch?.elapsedMilliseconds ?? 0} ms)');
    }

    // Ketukan pertama: aba-aba. Layar meredup ke material kamar gelap di
    // sini juga (lihat _material) — perhatian pindah ke lensa, dan tamu sudah
    // dapat cahaya dari layar terang selagi merapikan diri.
    setState(() {
      _step = _CaptureStep.countdown;
      _countdown.value = _cueValue;
    });
    await Future<void>.delayed(_cueDuration);
    if (!mounted) return;

    // Ketukan kedua: angka turun.
    final totalCountdown = _configuredCountdownSeconds;
    _countdown.value = totalCountdown;

    debugPrint('⏱️ [Perf] Timer hitungan mundur dimulai dari $totalCountdown '
        '(+${_perfWatch?.elapsedMilliseconds ?? 0} ms)');

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown.value > 1) {
        // TANPA setState: hanya pendengar notifier yang dibangun ulang.
        _countdown.value = _countdown.value - 1;
        final at = _perfWatch?.elapsedMilliseconds ?? 0;
        final shown = _countdown.value;
        // Selisih antara detak dan saat frame benar-benar tergambar
        // menunjukkan seberapa lama UI thread tersumbat.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final drawn = _perfWatch?.elapsedMilliseconds ?? 0;
          debugPrint('⏱️ [Perf] angka $shown '
              '— detak +$at ms, tergambar +$drawn ms '
              '(tertunda ${drawn - at} ms)');
        });
        // Kunci fokus satu hitungan sebelum jepret. AF butuh ~0,8 detik; kalau
        // baru dimulai saat hitungan habis, rana terasa telat sedetik.
        // Dijalankan tanpa ditunggu supaya hitungan mundur tetap presisi.
        if (_countdown.value == totalCountdown - 1) {
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
      flipX: _cameraPreviewFlipX,
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

  /// Nilai flip untuk `CameraPreview`.
  ///
  /// KEBALIKAN dari `_isMirrorEnabled`, dan itu disengaja.
  ///
  /// `camera_windows` sudah mencermin sendiri perangkat yang dilaporkan
  /// Windows sebagai `front` — dan capture card MS2109 dilaporkan begitu,
  /// meski sebenarnya kamera eksternal. Jadi frame yang sampai ke widget
  /// SUDAH ter-cermin. Menerapkan flip lagi saat Mirror ON justru
  /// membatalkannya dan preview berubah jadi seperti kamera belakang.
  ///
  /// Dengan kompensasi ini:
  ///   Mirror ON  -> flipX=false -> frame tetap ter-cermin  -> selfie  ✓
  ///   Mirror OFF -> flipX=true  -> cerminan dibatalkan     -> normal  ✓
  ///
  /// Hanya berlaku untuk `CameraPreview`. `UvcPreview` (jalur Android) tidak
  /// disentuh karena tumpukan preview-nya berbeda dan sudah benar di sana.
  bool get _cameraPreviewFlipX => !_isMirrorEnabled;

  /// Satu-satunya tempat nilai mirror berubah.
  ///
  /// Menulis ke sesi sekaligus, supaya pilihan tamu bertahan saat layar ini
  /// dibuat ulang untuk pose berikutnya.
  void _toggleMirror() {
    final next = !_isMirrorEnabled;
    setState(() => _isMirrorEnabled = next);
    ref.read(sessionNotifierProvider.notifier).setMirror(next);
    debugPrint('🪞 [Mirror] state=$next '
        'preview=${next ? "mirrored" : "normal"} '
        'result=${next ? "mirrored" : "normal"}');
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

        // Mulai memperkecil foto SEKARANG — selagi tamu meninjau hasilnya.
        //
        // Dulu ini dipanggil di _onNext, yaitu tepat saat tombol Lanjut ditekan
        // dan hitungan mundur berikutnya dimulai. Pekerjaannya ~1,5 detik plus
        // penyalinan 7 MB antar-isolate, jadi hitungan mundur tersendat dan
        // angkanya melompat: dari 7 tahu-tahu 3.
        //
        // Jendela peninjauan adalah waktu menganggur yang sesungguhnya — tidak
        // ada animasi, tidak ada hitungan, dan tamu sedang melihat foto.
        PhotoUploadPrepService.instance.warm(processedFile.path);
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

  /// [source] hanya untuk log — TIDAK ikut menentukan mirror.
  Future<XFile> _processCapturedPhoto(
    XFile rawFile,
    bool isMirrored, {
    required CaptureSource source,
  }) async {
    // SATU sumber keputusan: state tombol Mirror. Preview dan berkas hasil
    // memakai nilai yang sama persis, sehingga keduanya tidak mungkin berbeda.
    //
    // `lensDirection` SENGAJA tidak dipakai di mana pun. Di Windows capture
    // card dilaporkan sebagai `front` padahal ia kamera eksternal Sony, dan
    // memakainya sebagai penentu pernah membalik seluruh logika cermin.
    final needsFlip = isMirrored;

    debugPrint('🪞 [Mirror] state=$isMirrored '
        'preview=${isMirrored ? "mirrored" : "normal"} '
        'result=${needsFlip ? "mirrored" : "normal"} '
        '(sumber=${source.name})');

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
            .fold<BytesBuilder>(
              BytesBuilder(),
              (b, d) => b..add(d),
            );
        size = _readJpegSizeFromHeader(head.takeBytes());
      } catch (_) {}
      debugPrint('🪞 [Mirror Result] mirror=false → NO FLIP → '
          'gunakan foto asli');
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

      final prepared = await compute(_flipAndEncodeDart, raw);
      if (prepared == null) {
        debugPrint('⚠️ [ImageProcessor] Gagal memproses — memakai berkas asli '
            '(hasil TIDAK ter-cermin)');
        return rawFile;
      }

      // Hasil ter-flip ditulis DI SAMPING berkas aslinya, bukan di folder
      // sementara yang tersembunyi.
      //
      // Sebelumnya hasil disimpan di %TEMP%, sehingga folder Pictures hanya
      // berisi foto asli yang memang tidak ter-cermin. Saat diperiksa, hasilnya
      // tampak "tidak ter-flip" padahal berkas yang dipakai sesi sudah benar.
      // Sekarang keduanya berdampingan dan bisa dibandingkan langsung.
      final name = rawFile.path.split(dart_io.Platform.pathSeparator).last;
      final dot = name.lastIndexOf('.');
      final mirroredName = dot > 0
          ? '${name.substring(0, dot)}_mirror${name.substring(dot)}'
          : '${name}_mirror.jpg';
      final outFile = dart_io.File(
        '${file.parent.path}${dart_io.Platform.pathSeparator}$mirroredName',
      );
      await outFile.writeAsBytes(prepared.bytes, flush: true);
      await FileImage(outFile).evict();

      debugPrint('🪞 [Mirror Result] mirror=true → FLIP HORIZONTAL → '
          'hasil disimpan: ${outFile.path}');

      final src = srcSize == null
          ? '${prepared.width}x${prepared.height}'
          : '${srcSize.width}x${srcSize.height}';
      debugPrint('🖼️ [ImageProcessor] $src → '
          '${prepared.width}x${prepared.height} | mirror=true | '
          'decode=${prepared.decodeMs}ms flip=${prepared.flipMs}ms '
          'encode=${prepared.encodeMs}ms '
          'total=${swTotal.elapsedMilliseconds}ms');

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

  Future<void> _onNext() async {
    if (_isNavigating) return;
    _perfWatch = Stopwatch()..start();  // ganti penanda untuk pose berikutnya
    debugPrint('⏱️ [Perf] Lanjut ditekan');
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
      setState(() => _isNavigating = true);
      _countdownTimer?.cancel();

      // Gracefully release camera controller sebelum berpindah rute
      // untuk mencegah crash DirectX / native surface di Windows desktop & Android
      final cam = _cameraController;
      _cameraController = null;
      if (cam != null) {
        try {
          await cam.dispose();
        } catch (e) {
          debugPrint('⚠️ [CameraScreen] Cam dispose error during next: $e');
        }
      }

      if (_showUvcView || _isUvcReady) {
        if (mounted) {
          setState(() {
            _showUvcView = false;
            _isUvcReady = false;
            _isCameraReady = false;
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;
      context.go(AppRoutes.filter);
    } else {
      setState(() {
        _currentPose = nextPoseIndex;
      });
      _startCountdown();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Kamera adalah SATU-SATUNYA layar yang berpindah material, dan alasannya
  /// praktis bukan estetis: layar kiosk berfungsi sebagai lampu isi untuk
  /// wajah tamu. Layar gelap sepanjang sesi berarti wajah hanya disinari
  /// lampu kafe.
  ///
  ///   merapikan diri -> kertas (layar terang, jadi sumber cahaya)
  ///   aba-aba dan seterusnya -> kamar gelap (perhatian pindah ke lensa)
  BoothMaterial get _material => _step == _CaptureStep.initialPreview
      ? BoothMaterial.paper
      : BoothMaterial.bench;

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final selectedFrame = sessionState.selectedFrame;
    final isMobile = context.isMobile;

    return PopScope(
      canPop: false,
      child: PhotoboothLayout(
        material: _material,
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
                  liveCameraPreview: _kStripLivePreview &&
                          (_step == _CaptureStep.initialPreview ||
                              _step == _CaptureStep.countdown)
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
          opaqueOverlay: true,
          overlayChild: const Center(
            child: CircularProgressIndicator(
              color: AppColors.light60,
              strokeWidth: 2,
            ),
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
        color: AppColors.bench,
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
                  color: AppColors.light30,
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

  Widget _buildCameraViewfinder({
    required bool showOverlay,
    Widget? overlayChild,
    bool opaqueOverlay = false,
  }) {
    return AspectRatio(
      aspectRatio: _viewfinderAspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bench,
          // Jendela bidik adalah jendela, bukan kartu: radius cetak, garis
          // rambut, nol bayangan.
          borderRadius: BorderRadius.circular(AppGeometry.radiusPrint),
          border: Border.all(
            color: _material.rule,
            width: AppGeometry.hairline,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppGeometry.radiusPrint),
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
                    flipX: _cameraPreviewFlipX,
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
                  color: AppColors.bench,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_prepMessage != null)
                          SizedBox(
                            width: 28.r,
                            height: 28.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.light60,
                            ),
                          )
                        else
                          Icon(
                            Icons.photo_camera_rounded,
                            size: 42.sp,
                            color: AppColors.light30,
                          ),
                        if (_prepMessage != null) ...[
                          SizedBox(height: 10.h),
                          Text(
                            _prepMessage!,
                            style: AppFonts.display(
                              color: AppColors.light60,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              if (showOverlay)
                Container(
                  // Saat menjepret, preview ditutup RAPAT.
                  //
                  // Lapisan 55% transparan membuat preview hidup masih terlihat
                  // bergerak setelah rana berbunyi — tamu melihat dirinya
                  // bergerak padahal fotonya sudah diambil, dan itu terbaca
                  // sebagai aplikasi yang menggantung. Saat hitungan mundur
                  // sebaliknya: preview justru harus tetap terlihat.
                  color: opaqueOverlay
                      ? AppColors.bench
                      : AppColors.scrim,
                ),
              if (overlayChild != null) overlayChild,

              // Tanda bidik — kurung sudut.
              //
              // Satu-satunya ornamen yang boleh ada di layar ini, dan dia
              // punya tugas: menyatakan "ini bingkainya", persis seperti
              // tanda bidik di jendela bidik kamera sungguhan.
              const Positioned.fill(
                child: IgnorePointer(child: _FramingMarks()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hamparan hitung mundur — dua ketukan.
  ///
  /// Ketukan 1 (`_cueValue`): aba-aba. Tamu diberi tahu harus melihat ke mana
  /// sebelum angka mulai turun.
  /// Ketukan 2: angka 3-2-1, DIPOTONG KERAS per detik.
  ///
  /// Versi sebelumnya memakai `scale(begin: 1.25)` pada tiap angka. Angka yang
  /// membesar-mengecil membaca sebagai aplikasi; mesin tidak memantul. Cincin
  /// progres melingkar juga dilepas — deret tanda di bawah angka menyampaikan
  /// sisa hitungan lebih cepat daripada busur yang menyusut.
  Widget _buildCleanCountdownOverlay() {
    return Center(
      child: ValueListenableBuilder<int>(
        valueListenable: _countdown,
        builder: (context, value, _) {
          if (value == _cueValue) {
            return Text(
              'LIHAT KE LENSA',
              textAlign: TextAlign.center,
              style: AppFonts.ui(
                color: AppColors.light,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 5.0,
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value', style: AppTextStyles.countdownNumber),
              SizedBox(height: AppGeometry.s16.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_configuredCountdownSeconds, (i) {
                  final spent = i >= value;
                  return Container(
                    width: 26.w,
                    height: 2,
                    margin: EdgeInsets.symmetric(horizontal: AppGeometry.s4.w),
                    color: spent ? AppColors.light30 : AppColors.light,
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Kendali bawah ─────────────────────────────────────────────────────────

  Widget _buildBottomControls(bool isMobile) {
    switch (_step) {
      case _CaptureStep.initialPreview:
        return Row(
          children: [
            Expanded(
              child: ResponsiveButton(
                label: _isMirrorEnabled ? 'Mirror' : 'No Mirror',
                icon: null,
                variant: _isMirrorEnabled
                    ? ButtonVariant.primary
                    : ButtonVariant.outlined,
                material: _material,
                onPressed: _toggleMirror,
              ),
            ),
            SizedBox(width: AppGeometry.s12.w),
            Expanded(
              child: ResponsiveButton(
                label: 'Mulai',
                material: _material,
                onPressed: _startCountdown,
              ),
            ),
          ],
        );

      case _CaptureStep.result:
        return Row(
          children: [
            Expanded(
              child: ResponsiveButton(
                label: 'Ulangi',
                variant: ButtonVariant.outlined,
                material: _material,
                onPressed: _onRetake,
              ),
            ),
            SizedBox(width: AppGeometry.s12.w),
            Expanded(
              child: ResponsiveButton(
                label: 'Lanjut',
                material: _material,
                onPressed: _onNext,
              ),
            ),
          ],
        );

      case _CaptureStep.countdown:
      case _CaptureStep.capturing:
        // Ruang tetap supaya jendela bidik tidak melompat ukurannya saat
        // tombol menghilang.
        return SizedBox(height: AppGeometry.touchTarget.h);
    }
  }
}

/// Tanda bidik — kurung sudut di dalam jendela bidik.
class _FramingMarks extends StatelessWidget {
  const _FramingMarks();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FramingMarksPainter());
  }
}

class _FramingMarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.light.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    final inset = size.shortestSide * 0.045;
    final arm = size.shortestSide * 0.07;
    final l = inset, t = inset;
    final r = size.width - inset, b = size.height - inset;

    for (final (x, y, dx, dy) in [
      (l, t, 1.0, 1.0),
      (r, t, -1.0, 1.0),
      (l, b, 1.0, -1.0),
      (r, b, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + arm * dx, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + arm * dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
