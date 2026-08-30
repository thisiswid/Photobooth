import 'dart:async';
import 'dart:io' as dart_io;

import 'package:flutter/foundation.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sony_ptp_camera_service.dart';

/// UvcCameraService
///
/// Jalur LIVE PREVIEW photobooth: stream video dari HDMI capture card
/// (MacroSilicon MS2109 dll.) yang tersambung ke HDMI-out kamera Sony ZV-E10.
///
/// ────────────────────────────────────────────────────────────────────────────
/// PENTING — KETERBATASAN PLUGIN (sumber bug preview hitam & app freeze):
///
/// `UVCCameraViewFactory` di sisi Android menyimpan HANYA SATU referensi view:
///
///     private lateinit var cameraView: UVCCameraView
///     override fun create(...) { cameraView = UVCCameraView(...) }   // ditimpa!
///
/// Artinya setiap kali sebuah `UVCCameraView` baru dibuat (pindah halaman),
/// SEMUA perintah native (`openUVCCamera`, `takePicture`, `closeCamera`)
/// otomatis dialihkan ke view TERBARU. View lama menjadi yatim.
///
/// Konsekuensinya:
///  - Status "sudah terbuka" dari halaman sebelumnya TIDAK berlaku untuk view
///    baru. Kalau kita men-skip `openUVCCamera()` karena mengira kamera masih
///    terbuka, view baru tidak pernah dibuka → PREVIEW HITAM.
///  - `takePicture()` dikirim ke view yang tidak terbuka → callback native
///    tidak pernah dipanggil → Future menggantung → UI TERASA HANG / ANR.
///
/// Solusi di kelas ini: penomoran generasi view (`_viewGeneration`).
/// Setiap `UvcPreview` yang mount menaikkan generasi dan membatalkan status
/// open sebelumnya, sehingga setiap halaman selalu melakukan open ulang.
/// Semua panggilan native juga diberi timeout agar UI tidak pernah menggantung.
/// ────────────────────────────────────────────────────────────────────────────
class UvcCameraService {
  UvcCameraService._();
  static final UvcCameraService instance = UvcCameraService._();

  UVCCameraController? _controller;
  bool _isOpen = false;
  bool _initialized = false;
  String? _lastError;

  /// Dinaikkan setiap kali sebuah UVCCameraView baru ter-mount.
  int _viewGeneration = 0;

  /// Generasi view yang benar-benar berhasil dibuka.
  int _openedGeneration = -1;

  /// Mencegah dua proses open berjalan bersamaan.
  Future<bool>? _pendingOpen;

  final StreamController<bool> _openStateController =
      StreamController<bool>.broadcast();

  Stream<bool> get openState => _openStateController.stream;

  UVCCameraController get controller {
    _controller ??= UVCCameraController();
    return _controller!;
  }

  /// Kamera terbuka DAN yang terbuka adalah view yang sedang tampil sekarang.
  bool get isOpen => _isOpen && _openedGeneration == _viewGeneration;

  String? get lastError => _lastError;
  int get viewGeneration => _viewGeneration;

  // ── Lifecycle view ────────────────────────────────────────────────────────

  /// Dipanggil oleh `UvcPreview` saat sebuah UVCCameraView baru ter-mount.
  /// Mengembalikan nomor generasi view tersebut.
  int attachView() {
    _viewGeneration++;
    // Status open milik view lama tidak berlaku lagi — factory native sudah
    // menunjuk ke view yang baru ini.
    _isOpen = false;
    debugPrint('📹 [UvcCameraService] View attach → generasi $_viewGeneration');
    return _viewGeneration;
  }

  /// Dipanggil saat sebuah UVCCameraView unmount.
  void detachView(int generation) {
    if (generation != _viewGeneration) {
      // View lama yang di-dispose SETELAH halaman baru mount — abaikan supaya
      // tidak mematikan kamera halaman yang sedang aktif.
      debugPrint('📹 [UvcCameraService] Abaikan detach view lama (gen $generation)');
      return;
    }
    debugPrint('📹 [UvcCameraService] View detach (gen $generation) → tutup kamera');
    close();
  }

  void init() {
    if (_initialized && _controller != null) return;
    final c = controller;
    c.cameraStateCallback = (state) {
      debugPrint('📹 [UvcCameraService] state: $state (gen $_viewGeneration)');
      switch (state) {
        case UVCCameraState.opened:
          _isOpen = true;
          _openedGeneration = _viewGeneration;
          _lastError = null;
          break;
        case UVCCameraState.closed:
        case UVCCameraState.error:
          _isOpen = false;
          break;
      }
      if (!_openStateController.isClosed) _openStateController.add(_isOpen);
    };
    c.msgCallback = (msg) {
      debugPrint('📹 [UvcCameraService] msg native: $msg');
      if (msg.toLowerCase().contains('permission') ||
          msg.toUpperCase().contains('ERROR')) {
        _lastError = msg;
      }
    };
    _initialized = true;
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> ensurePermissions() async {
    var camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) {
      camStatus = await Permission.camera.request();
    }
    if (!camStatus.isGranted) {
      _lastError = 'Izin Kamera Android ditolak. Buka Settings → Apps → '
          'SnapTechBooth → Permissions → Camera → Allow.';
      debugPrint('❌ [UvcCameraService] $_lastError');
      return false;
    }

    try {
      final status = await SonyPtpCameraService.getStatus()
          .timeout(const Duration(seconds: 5));
      if (status.uvcDetected && !status.uvcHasPermission) {
        debugPrint('📹 [UvcCameraService] Minta izin USB capture card...');
        final granted = await SonyPtpCameraService.requestUvcPermission()
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
        debugPrint('📹 [UvcCameraService] Izin USB capture card: $granted');
      }
    } catch (e) {
      debugPrint('⚠️ [UvcCameraService] Cek izin USB gagal: $e');
    }
    return true;
  }

  // ── Open ──────────────────────────────────────────────────────────────────

  /// Buka UVC camera untuk view yang sedang aktif.
  ///
  /// Selalu memanggil `openUVCCamera()` untuk generasi view saat ini — TIDAK
  /// pernah men-skip berdasarkan status open halaman sebelumnya (lihat catatan
  /// keterbatasan plugin di atas).
  Future<bool> open({
    Duration timeout = const Duration(seconds: 12),
    bool requestPermissions = true,
  }) {
    // Kalau sudah ada proses open untuk generasi yang sama, ikut menunggu.
    final pending = _pendingOpen;
    if (pending != null) return pending;

    final future = _open(timeout: timeout, requestPermissions: requestPermissions);
    _pendingOpen = future;
    return future.whenComplete(() => _pendingOpen = null);
  }

  Future<bool> _open({
    required Duration timeout,
    required bool requestPermissions,
  }) async {
    try {
      init();

      if (requestPermissions) {
        final ok = await ensurePermissions();
        if (!ok) return false;
      }

      final gen = _viewGeneration;

      // Sudah terbuka untuk view INI — tidak perlu apa-apa lagi.
      if (_isOpen && _openedGeneration == gen) {
        debugPrint('✅ [UvcCameraService] Kamera sudah terbuka untuk gen $gen');
        return true;
      }

      await controller
          .openUVCCamera()
          .timeout(const Duration(seconds: 5), onTimeout: () {});
      debugPrint('📹 [UvcCameraService] openUVCCamera() dikirim (gen $gen)');

      final deadline = DateTime.now().add(timeout);
      var attempt = 0;
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 250));
        attempt++;

        // View berganti di tengah proses — batalkan, biar view baru yang urus.
        if (_viewGeneration != gen) {
          debugPrint('📹 [UvcCameraService] View berganti saat open — batal (gen $gen)');
          return false;
        }
        if (_isOpen) {
          _openedGeneration = gen;
          _lastError = null;
          debugPrint('✅ [UvcCameraService] Terbuka setelah ${attempt * 250}ms (gen $gen)');
          unawaited(_verifyResolution());
          return true;
        }
        // Retry sekali di pertengahan (mis. user baru menekan Allow izin USB).
        if (attempt == 16) {
          debugPrint('📹 [UvcCameraService] Retry openUVCCamera() (gen $gen)');
          try {
            await controller
                .openUVCCamera()
                .timeout(const Duration(seconds: 5), onTimeout: () {});
          } catch (_) {}
        }
      }

      _lastError = _lastError ??
          'Preview HDMI tidak merespons dalam ${timeout.inSeconds} detik. '
              'Cek kabel HDMI ke capture card, kamera menyala dengan HDMI output '
              'aktif, dan izin USB sudah di-Allow.';
      debugPrint('❌ [UvcCameraService] Timeout open: $_lastError');
      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('⚠️ [UvcCameraService] Gagal open: $e');
      return false;
    }
  }

  /// Laporkan resolusi yang benar-benar dinegosiasikan dengan capture card,
  /// dan koreksi SEKALI bila masih terjebak di default kecil.
  ///
  /// Plugin memakai default 640x480 (4:3) bila previewWidth/Height tidak
  /// dikirim — itu membuat preview salah rasio dan foto hanya 0.3 MP.
  bool _resolutionCorrected = false;

  Future<void> _verifyResolution({
    int wantWidth = 1920,
    int wantHeight = 1080,
  }) async {
    try {
      final raw = await controller
          .getCurrentCameraRequestParameters()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      debugPrint('📹 [UvcCameraService] Resolusi aktif: $raw');
      if (raw == null || _resolutionCorrected) return;

      // Ambil angka lebar/tinggi secara eksplisit — JANGAN pakai
      // raw.contains('640'), itu ikut cocok pada angka lain (mis. 1640)
      // dan bisa memicu updateResolution berulang → preview restart terus.
      final w = int.tryParse(
        RegExp(r'"previewWidth"\s*:\s*(\d+)').firstMatch(raw)?.group(1) ?? '',
      );
      final h = int.tryParse(
        RegExp(r'"previewHeight"\s*:\s*(\d+)').firstMatch(raw)?.group(1) ?? '',
      );
      if (w == null || h == null) return;
      if (w >= wantWidth && h >= wantHeight) return;

      _resolutionCorrected = true;
      debugPrint('📹 [UvcCameraService] Resolusi ${w}x$h terlalu kecil — '
          'paksa ke ${wantWidth}x$wantHeight');
      controller.updateResolution(
        PreviewSize(width: wantWidth, height: wantHeight),
      );
    } catch (e) {
      debugPrint('⚠️ [UvcCameraService] _verifyResolution: $e');
    }
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Ambil satu frame dari stream HDMI.
  ///
  /// Diberi timeout keras: callback native `ICaptureCallBack` bisa TIDAK PERNAH
  /// dipanggil bila kamera dalam kondisi setengah rusak, dan tanpa timeout
  /// Future ini menggantung selamanya sehingga UI terlihat hang.
  Future<dart_io.File?> takePhoto({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!isOpen) {
      _lastError = 'Kamera HDMI belum terbuka (gen $_viewGeneration).';
      debugPrint('❌ [UvcCameraService] takePhoto dibatalkan: $_lastError');
      return null;
    }
    try {
      final path = await controller.takePicture().timeout(
        timeout,
        onTimeout: () {
          debugPrint('❌ [UvcCameraService] takePicture TIMEOUT ${timeout.inSeconds}s');
          return null;
        },
      );
      if (path != null && path.isNotEmpty) {
        final file = dart_io.File(path);
        if (file.existsSync() && file.lengthSync() > 0) return file;
        debugPrint('⚠️ [UvcCameraService] File capture kosong/hilang: $path');
      }
      _lastError = 'Gagal mengambil frame dari stream HDMI.';
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ [UvcCameraService] takePhoto error: $e');
      return null;
    }
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  void close() {
    try {
      _controller?.closeCamera();
    } catch (e) {
      debugPrint('⚠️ [UvcCameraService] closeCamera error: $e');
    }
    _isOpen = false;
    _openedGeneration = -1;
    if (!_openStateController.isClosed) _openStateController.add(false);
  }

  /// Jangan dipanggil saat berpindah halaman — controller ini singleton dan
  /// dipakai bersama oleh semua layar. Hanya untuk shutdown aplikasi.
  void dispose() {
    try {
      close();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initialized = false;
  }
}
