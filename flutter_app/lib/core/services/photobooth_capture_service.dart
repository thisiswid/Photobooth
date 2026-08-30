import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sony_ptp_camera_service.dart';
import 'uvc_camera_service.dart';

/// Jalur mana yang dipakai untuk sebuah sesi photobooth.
enum CaptureMode {
  /// HDMI capture card untuk preview + PTP (kabel C-to-C) untuk shutter.
  /// Ini mode terbaik: preview 1080p mulus + foto resolusi penuh 24MP.
  hybrid,

  /// Hanya HDMI capture card. Preview mulus, tapi "foto" hanyalah grab frame
  /// video 1920x1080 (~2MP) — kualitas cetak 4R menurun.
  hdmiOnly,

  /// Hanya kabel C-to-C PTP. Foto resolusi penuh, tapi tidak ada live preview
  /// (layar preview memakai kamera tablet sebagai pemandu framing).
  ptpOnly,

  /// Tidak ada kamera eksternal — pakai kamera tablet.
  tabletOnly,
}

/// Sumber sebuah foto hasil capture.
enum CaptureSource { ptp, uvc, tablet }

class CaptureOutcome {
  const CaptureOutcome({
    required this.success,
    required this.source,
    this.file,
    this.message = '',
  });

  final bool success;
  final CaptureSource source;
  final File? file;
  final String message;
}

/// PhotoboothCaptureService
///
/// Lapisan tunggal yang memutuskan jalur preview & jalur shutter, lalu
/// menjalankan capture dengan fallback berlapis.
///
/// ARSITEKTUR YANG DIPILIH — HYBRID (2 kabel):
///
///   Sony ZV-E10 ──HDMI──> USB Capture Card ──┐
///                                            ├──> USB Hub bertenaga ──> Tablet
///   Sony ZV-E10 ──USB C-to-C (PC Remote)─────┘
///
/// - LIVE PREVIEW  : dari capture card (UVC). Mulus, 1080p, latency rendah.
/// - SHUTTER/FOTO  : dari PTP (kabel C-to-C). Shutter mekanik kamera,
///                   autofocus penuh, JPEG resolusi penuh (6000x4000 / 24MP).
///
/// Alasan tidak memakai HDMI saja: frame HDMI hanya 1920x1080 (2.07MP).
/// Untuk cetak 4R (4x6 inci) pada 300 DPI dibutuhkan 1200x1800 px; setelah
/// di-crop ke rasio 2:3 sebuah frame 1080p hanya menyisakan ~720x1080 px
/// (~0.78MP) — hasil cetak terlihat lunak/pecah.
///
/// Alasan tidak memakai C-to-C saja: PTP tidak memberi stream preview yang
/// layak (liveview Sony hanya ~640x480 beberapa fps), sehingga pengalaman
/// kiosk terasa patah-patah.
///
/// Kedua kabel TIDAK bentrok: capture card dan kamera adalah dua perangkat USB
/// berbeda (VID 0x534D vs 0x054C) dengan driver berbeda (UVC vs PTP).
/// Syarat: pakai USB hub bertenaga (powered hub), dan di kamera set
/// MENU → Setup → USB → USB Connection = **PC Remote** (JANGAN "USB Streaming",
/// karena mode itu mematikan output HDMI).
class PhotoboothCaptureService {
  PhotoboothCaptureService._();
  static final PhotoboothCaptureService instance = PhotoboothCaptureService._();

  CaptureMode _mode = CaptureMode.tabletOnly;
  bool _ptpReady = false;
  bool _uvcReady = false;
  String _lastDiagnostic = '';

  CaptureMode get mode => _mode;
  bool get ptpReady => _ptpReady;
  bool get uvcReady => _uvcReady;
  String get lastDiagnostic => _lastDiagnostic;

  /// True bila layar preview harus me-render `UVCCameraView`.
  bool get usesUvcPreview =>
      _mode == CaptureMode.hybrid || _mode == CaptureMode.hdmiOnly;

  /// Deteksi perangkat & tentukan mode. Panggil sekali saat masuk layar kamera.
  Future<CaptureMode> detectMode() async {
    final status = await SonyPtpCameraService.getStatus();
    debugPrint(
      '🔎 [Capture] SDK=${status.androidSdkInt} '
      'uvc=${status.uvcDetected}(perm=${status.uvcHasPermission}, ${status.uvcProductName}) '
      'ptp=${status.ptpDetected}(perm=${status.ptpHasPermission}, ${status.ptpProductName})',
    );

    if (status.uvcDetected && status.ptpDetected) {
      _mode = CaptureMode.hybrid;
    } else if (status.uvcDetected) {
      _mode = CaptureMode.hdmiOnly;
    } else if (status.ptpDetected) {
      _mode = CaptureMode.ptpOnly;
    } else {
      _mode = CaptureMode.tabletOnly;
    }
    _lastDiagnostic = describeMode(_mode);
    debugPrint('🎯 [Capture] Mode dipilih: $_lastDiagnostic');
    return _mode;
  }

  static String describeMode(CaptureMode mode) {
    switch (mode) {
      case CaptureMode.hybrid:
        return 'HYBRID — preview HDMI + shutter PTP (kualitas terbaik)';
      case CaptureMode.hdmiOnly:
        return 'HDMI ONLY — preview & foto dari capture card (foto ~2MP)';
      case CaptureMode.ptpOnly:
        return 'PTP ONLY — foto resolusi penuh, preview dari kamera tablet';
      case CaptureMode.tabletOnly:
        return 'TABLET ONLY — tidak ada kamera eksternal terdeteksi';
    }
  }

  Future<bool>? _shutterFuture;

  /// Mulai menyiapkan jalur shutter PTP TANPA menunggu selesai.
  ///
  /// Handshake PTP (device reset + OpenSession + 3 fase SDIO) memakan
  /// beberapa detik. Menunggunya sebelum menampilkan preview membuat layar
  /// kamera gelap lama — itu sebabnya gambar baru muncul di hitungan ke-3.
  /// Preview HDMI tidak bergantung pada PTP, jadi keduanya dijalankan paralel.
  void startShutterPath() {
    _shutterFuture ??= prepareShutterPath();
  }

  /// Tunggu jalur shutter selesai disiapkan, dengan batas waktu.
  /// Dipanggil tepat sebelum menjepret, bukan saat membuka halaman.
  Future<void> awaitShutterPath({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final f = _shutterFuture;
    if (f == null) return;
    try {
      await f.timeout(timeout, onTimeout: () => false);
    } catch (_) {}
  }

  /// Siapkan jalur PTP (kabel C-to-C): minta izin USB lalu buka sesi PTP.
  /// Aman dipanggil walau kabel C-to-C tidak terpasang.
  Future<bool> prepareShutterPath() async {
    _ptpReady = false;
    if (_mode != CaptureMode.hybrid && _mode != CaptureMode.ptpOnly) {
      return false;
    }
    try {
      final status = await SonyPtpCameraService.getStatus()
          .timeout(const Duration(seconds: 5));
      if (!status.ptpDetected) return false;

      if (!status.ptpHasPermission) {
        final granted = await SonyPtpCameraService.requestPermission()
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
        if (!granted) {
          _lastDiagnostic = 'Izin USB kamera Sony ditolak — shutter PTP nonaktif.';
          debugPrint('⚠️ [Capture] $_lastDiagnostic');
          return false;
        }
      }

      _ptpReady = await SonyPtpCameraService.connect()
          .timeout(const Duration(seconds: 15), onTimeout: () => false);
      if (!_ptpReady) {
        _lastDiagnostic =
            'Gagal membuka sesi PTP. Cek: MENU → Setup → USB → USB Connection = PC Remote, '
            'dan Network → PC Remote Function → PC Remote = ON.';
        debugPrint('⚠️ [Capture] $_lastDiagnostic');
      } else {
        debugPrint('✅ [Capture] Jalur shutter PTP siap.');
      }
      return _ptpReady;
    } catch (e) {
      debugPrint('⚠️ [Capture] prepareShutterPath error: $e');
      return false;
    }
  }

  /// Dilaporkan oleh widget `UvcPreview` setelah percobaan open selesai.
  ///
  /// Open TIDAK dilakukan di sini: `UVCCameraViewFactory` native hanya
  /// menyimpan satu referensi view, jadi hanya widget yang sedang ter-mount
  /// yang tahu generasi view mana yang valid untuk dibuka.
  void markPreviewReady(bool ready) {
    _uvcReady = ready;
    if (!ready) {
      _lastDiagnostic =
          UvcCameraService.instance.lastError ?? 'Preview HDMI gagal dibuka.';
      debugPrint('⚠️ [Capture] $_lastDiagnostic');
    }
  }

  /// Ambil satu foto memakai jalur terbaik yang tersedia.
  ///
  /// Urutan prioritas:
  ///   1. PTP  — shutter mekanik, JPEG resolusi penuh (terbaik untuk cetak)
  ///   2. UVC  — grab frame HDMI 1080p (fallback bila PTP gagal/tidak ada)
  ///   3. null — pemanggil harus fallback ke kamera tablet
  Future<CaptureOutcome> capture() async {
    // ── 1. PTP: shutter kamera asli ──────────────────────────────────────
    if (_ptpReady) {
      try {
        // Timeout keras: transfer JPEG 24MP lewat bulk USB bisa lama, tapi
        // tidak boleh membuat UI kiosk menggantung selamanya.
        final res = await SonyPtpCameraService.capturePhoto().timeout(
          const Duration(seconds: 20),
          onTimeout: () => const SonyCaptureResult(
            isSuccess: false,
            message: 'Timeout menunggu shutter PTP (20 detik).',
          ),
        );
        if (res.isSuccess && res.filePath != null) {
          final f = File(res.filePath!);
          if (f.existsSync() && f.lengthSync() > 0) {
            debugPrint('📸 [Capture] Foto PTP: ${res.filePath} (${res.fileSizeBytes} bytes)');
            return CaptureOutcome(success: true, source: CaptureSource.ptp, file: f);
          }
        }
        debugPrint('⚠️ [Capture] PTP gagal (${res.message}) — fallback ke frame HDMI.');
      } catch (e) {
        debugPrint('⚠️ [Capture] PTP error: $e — fallback ke frame HDMI.');
      }
    }

    // ── 2. UVC: grab frame dari stream HDMI ──────────────────────────────
    // Pakai isOpen (bukan _uvcReady) supaya generasi view yang sudah tidak
    // valid tidak dipakai — itu penyebab capture menggantung sebelumnya.
    if (UvcCameraService.instance.isOpen) {
      final f = await UvcCameraService.instance.takePhoto();
      if (f != null) {
        debugPrint('📸 [Capture] Foto frame-grab HDMI: ${f.path}');
        return CaptureOutcome(
          success: true,
          source: CaptureSource.uvc,
          file: f,
          message: _ptpReady ? 'Fallback dari PTP ke frame HDMI.' : '',
        );
      }
      debugPrint('⚠️ [Capture] Frame-grab HDMI gagal: '
          '${UvcCameraService.instance.lastError}');
    } else if (_uvcReady) {
      debugPrint('⚠️ [Capture] View UVC sudah tidak valid — lewati frame-grab.');
    }

    // ── 3. Serahkan ke pemanggil (kamera tablet) ─────────────────────────
    return const CaptureOutcome(
      success: false,
      source: CaptureSource.tablet,
      message: 'Jalur kamera eksternal tidak tersedia — memakai kamera tablet.',
    );
  }

  /// Lepaskan HANYA sesi PTP.
  ///
  /// Kamera UVC sengaja TIDAK ditutup di sini: controller-nya singleton dan
  /// dipakai bersama semua layar. Menutupnya saat berpindah halaman akan
  /// mematikan preview halaman berikutnya. Siklus hidup view UVC ditangani
  /// oleh widget `UvcPreview`.
  Future<void> releasePtp() async {
    try {
      if (_ptpReady) await SonyPtpCameraService.disconnect();
    } catch (_) {}
    _ptpReady = false;
    _shutterFuture = null;
  }
}
