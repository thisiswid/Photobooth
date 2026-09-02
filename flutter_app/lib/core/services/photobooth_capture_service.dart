import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'camera_service.dart';
import 'sony_camera_helper_client.dart';
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

  /// WINDOWS: preview DAN foto dari satu perangkat kamera yang dikenali
  /// Windows sebagai webcam biasa — biasanya HDMI capture card.
  ///
  /// Di Windows tidak ada jalur UVC khusus seperti di Android: MediaFoundation
  /// sudah menyajikan capture card sebagai kamera standar, sehingga plugin
  /// `camera` (lewat `camera_windows`) menangani preview sekaligus jepretan.
  /// Seluruh fork `flutter_uvc_camera` beserta workaround generasi view-nya
  /// tidak terpakai sama sekali di sini.
  ///
  /// Kualitas foto mengikuti resolusi capture card (umumnya 1080p, ~2 MP).
  /// Untuk 24 MP tetap dibutuhkan jalur PTP — itu Cycle C4.
  windowsCamera,

  /// WINDOWS: preview dari capture card (MediaFoundation) + shutter dari
  /// Sony ZV-E10 lewat `sony_camera_helper.exe` (Camera Control PTP).
  ///
  /// Ini padanan Windows dari [hybrid]: preview mulus 1080p dari HDMI,
  /// foto 6000x4000 (24 MP) dari sensor kamera. Bedanya dengan Android,
  /// shutter berjalan di proses terpisah sehingga lapisan kamera yang
  /// menggantung tidak ikut membekukan kiosk.
  windowsSony,
}

/// Sumber sebuah foto hasil capture.
enum CaptureSource { ptp, uvc, tablet, sonyRemote }

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

  /// Mode yang dipilih saat deteksi, sebelum degradasi apa pun.
  CaptureMode _intendedMode = CaptureMode.tabletOnly;
  String _degradedReason = '';

  CaptureMode get mode => _mode;
  bool get ptpReady => _ptpReady;
  bool get uvcReady => _uvcReady;
  String get lastDiagnostic => _lastDiagnostic;

  /// True bila jalur yang sedang dipakai LEBIH BURUK dari yang seharusnya.
  /// Dilaporkan ke server lewat heartbeat supaya penurunan kualitas diam-diam
  /// tidak pernah terjadi tanpa ada yang tahu.
  bool get isDegraded => _mode != _intendedMode;
  CaptureMode get intendedMode => _intendedMode;
  String get degradedReason => _degradedReason;

  /// Nilai ringkas untuk heartbeat, mis. `windowsSony` atau
  /// `windowsCamera(from:windowsSony)` saat sedang terdegradasi.
  String get heartbeatCaptureMode => isDegraded
      ? '${_mode.name}(from:${_intendedMode.name})'
      : _mode.name;

  void _degradeTo(CaptureMode fallback, String reason) {
    if (_mode == fallback) return;
    _degradedReason = reason;
    debugPrint('⬇️ [Capture] DEGRADASI ${_mode.name} → ${fallback.name}: $reason');
    debugPrint('   Kualitas foto turun. Ini dilaporkan lewat heartbeat.');
    _mode = fallback;
  }

  /// True bila layar preview harus me-render `UVCCameraView`.
  bool get usesUvcPreview =>
      _mode == CaptureMode.hybrid || _mode == CaptureMode.hdmiOnly;

  /// Deteksi perangkat & tentukan mode. Panggil sekali saat masuk layar kamera.
  Future<CaptureMode> detectMode() async {
    // ── WINDOWS ───────────────────────────────────────────────────────────
    // SonyPtpCameraService bergantung pada USB Host API Android dan tidak
    // punya arti di sini. Yang dipakai: daftar kamera dari MediaFoundation.
    if (Platform.isWindows) {
      final cams = await CameraService.getAvailableCamerasList();
      _uvcReady = cams.isNotEmpty;
      _ptpReady = false;

      // Cek keberadaan helper saja (sekadar File.existsSync) — menjalankan dan
      // menyambungkannya butuh beberapa detik dan itu dikerjakan di latar oleh
      // startShutterPath(), supaya preview tidak tertahan.
      final helperInstalled = SonyCameraHelperClient.isInstalled;

      if (helperInstalled) {
        // Kamera Sony menentukan mode, bukan ada-tidaknya capture card.
        // Tanpa capture card preview memang kosong, tapi FOTO tetap 24 MP dari
        // sensor Sony — itu jauh lebih baik daripada jatuh ke tabletOnly dan
        // tidak bisa menjepret sama sekali. Ini padanan Windows dari mode
        // `ptpOnly` di Android.
        _mode = CaptureMode.windowsSony;
        _lastDiagnostic = cams.isEmpty
            ? 'WINDOWS — shutter dari helper Sony (24 MP). '
                'Tidak ada capture card: preview kosong, foto tetap jalan'
            : 'WINDOWS — preview dari capture card '
                '(${cams.length} kamera: ${cams.map((c) => c.name).join(", ")}), '
                'shutter dari helper Sony';
      } else if (cams.isEmpty) {
        _mode = CaptureMode.tabletOnly;
        _lastDiagnostic = 'WINDOWS — tidak ada kamera terdeteksi dan '
            'sony_camera_helper.exe tidak terpasang';
      } else {
        _mode = CaptureMode.windowsCamera;
        _lastDiagnostic = 'WINDOWS — ${cams.length} kamera terdeteksi: '
            '${cams.map((c) => c.name).join(", ")}. '
            'sony_camera_helper.exe tidak terpasang, foto memakai capture card (~2 MP)';
      }
      _intendedMode = _mode;
      _degradedReason = '';
      debugPrint('🎯 [Capture] $_lastDiagnostic');
      return _mode;
    }

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
    _intendedMode = _mode;
    _degradedReason = '';
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
      case CaptureMode.windowsCamera:
        return 'WINDOWS CAMERA — preview & foto dari capture card (~2 MP)';
      case CaptureMode.windowsSony:
        return 'WINDOWS SONY — preview HDMI + shutter Sony 24 MP';
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
    _shutterFuture ??= _prepareWithRetry().whenComplete(() => _shutterFuture = null);
  }

  /// Handshake PTP dengan satu kali percobaan ulang.
  ///
  /// Kegagalan paling sering disebabkan bus USB yang sedang sibuk oleh stream
  /// HDMI, dan biasanya berhasil pada percobaan kedua setelah jeda. Tanpa retry,
  /// satu kegagalan mematikan shutter PTP untuk SELURUH sesi dan semua foto
  /// diam-diam turun jadi frame-grab 1080p.
  Future<bool> _prepareWithRetry() async {
    if (await prepareShutterPath()) return true;

    debugPrint('🔁 [Capture] Handshake PTP gagal — mencoba sekali lagi dalam 2 detik...');
    await Future<void>.delayed(const Duration(seconds: 2));
    final ok = await prepareShutterPath();
    if (!ok) {
      debugPrint('❌ [Capture] Shutter PTP tidak tersedia. '
          'Foto akan memakai frame HDMI 1080p (bukan 24 MP).');
    }
    return ok;
  }

  /// Handshake PTP dengan stream HDMI DIHENTIKAN sementara.
  ///
  /// Ini bukan optimasi — ini syarat mutlak.
  ///
  /// Capture card dan kamera berbagi hub USB yang sama. Selama capture card
  /// streaming 1080p30, pembacaan balasan `OpenSession` dari kamera SELALU
  /// gagal: endpoint IN ter-stall dan responsnya kembali 0x0000, lalu seluruh
  /// perintah berikutnya ditolak 0x2003 (SessionNotOpen). Menambah jeda tidak
  /// menolong karena stream-nya tidak pernah berhenti sendiri.
  ///
  /// Bukti dari lapangan: handshake hanya berhasil ketika kebetulan berjalan
  /// di sela perpindahan halaman, yaitu saat UVCCameraView sedang tidak
  /// ter-mount dan stream mati.
  ///
  /// Karena sesi PTP dipakai ulang antar jepretan, jeda ini hanya perlu sekali
  /// di awal sesi foto.
  Future<bool> prepareShutterPathWithUvcPaused() async {
    // Di Windows tidak ada jeda stream. Masalah bus USB yang memaksa jeda itu
    // khas Android/libusb: di sana capture card dan kamera dibaca proses yang
    // sama lewat libusb, dan stream 1080p membuat balasan OpenSession stall.
    // Di Windows capture card dipegang MediaFoundation dan kamera dipegang
    // driver WIA/WPD — dua tumpukan driver terpisah, tidak saling mengunci.
    if (Platform.isWindows) return prepareShutterPath();

    if (_mode != CaptureMode.hybrid && _mode != CaptureMode.ptpOnly) return false;

    final uvcWasOpen = UvcCameraService.instance.isOpen;
    if (uvcWasOpen) {
      debugPrint('⏸️ [Capture] Menghentikan stream HDMI sementara untuk handshake PTP...');
      UvcCameraService.instance.close();
      // Beri waktu libusb melepas bus sepenuhnya.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    bool ok = false;
    try {
      ok = await _prepareWithRetry();
    } finally {
      if (uvcWasOpen) {
        debugPrint('▶️ [Capture] Menyalakan kembali stream HDMI...');
        final reopened = await UvcCameraService.instance.open();
        _uvcReady = reopened;
        if (!reopened) {
          debugPrint('⚠️ [Capture] Stream HDMI gagal dinyalakan ulang: '
              '${UvcCameraService.instance.lastError}');
        }
      }
    }
    return ok;
  }

  /// SATU-SATUNYA titik masuk penyiapan shutter dari layar kamera.
  ///
  /// Mengembalikan future yang sama bila penyiapan sedang berjalan, sehingga
  /// tidak akan pernah ada dua handshake bersamaan.
  ///
  /// Ini bukan sekadar optimasi. Dua handshake paralel pada perangkat USB yang
  /// sama saling menghancurkan: yang satu memanggil closeConnection() (yang
  /// meng-null-kan usbConnection dan endpoint) tepat saat yang lain sedang di
  /// tengah sendPtpCommand. Akibatnya sendPtpCommand keluar lewat early-return
  /// `usbConnection ?: return PtpResponse(0, null)` — DIAM-DIAM, tanpa log —
  /// dan hasilnya terbaca sebagai "OpenSession 0x0000", persis seperti gejala
  /// bus sibuk. Itulah kenapa menambah jeda tidak pernah menolong.
  Future<bool> ensureShutterPath() {
    return _shutterFuture ??= prepareShutterPathWithUvcPaused()
        .whenComplete(() => _shutterFuture = null);
  }

  /// Versi tembak-lupakan dari [ensureShutterPath].
  void startShutterPathWithUvcPaused() {
    unawaited(ensureShutterPath());
  }

  /// Tunggu jalur shutter selesai disiapkan, dengan batas waktu.
  /// Dipanggil tepat sebelum menjepret, bukan saat membuka halaman.
  Future<void> awaitShutterPath({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final f = _shutterFuture;
    if (f == null) return;
    debugPrint('⏳ [Capture] Menunggu penyiapan shutter selesai...');
    try {
      await f.timeout(timeout, onTimeout: () => false);
    } catch (_) {}
  }

  /// Siapkan jalur PTP (kabel C-to-C): minta izin USB lalu buka sesi PTP.
  /// Aman dipanggil walau kabel C-to-C tidak terpasang.
  Future<bool> prepareShutterPath() async {
    _ptpReady = false;

    // ── WINDOWS: jalankan helper lalu buka sesi kamera ────────────────────
    if (Platform.isWindows) {
      if (_mode != CaptureMode.windowsSony) return false;
      final helper = SonyCameraHelperClient.instance;
      try {
        if (!await helper.start()) {
          _lastDiagnostic = 'Helper kamera Sony gagal dijalankan: ${helper.lastError}';
          debugPrint('⚠️ [Capture] $_lastDiagnostic');
          return false;
        }
        _ptpReady = await helper.connectCamera();
        if (!_ptpReady) {
          _lastDiagnostic =
              'Gagal membuka sesi kamera Sony: ${helper.lastError}. '
              'Cek kabel USB dan MENU → Setup → USB → USB Connection = PC Remote.';
          debugPrint('⚠️ [Capture] $_lastDiagnostic');
        } else {
          debugPrint('✅ [Capture] Jalur shutter Sony (helper) siap.');
        }
        return _ptpReady;
      } catch (e) {
        _lastDiagnostic = 'prepareShutterPath (Windows) error: $e';
        debugPrint('⚠️ [Capture] $_lastDiagnostic');
        return false;
      }
    }

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
    // ── MODE WINDOWS-SONY: shutter lewat helper, 24 MP ────────────────────
    //
    // Aturan yang sama dengan jalur Android berlaku di sini: kegagalan TIDAK
    // boleh diam-diam diganti frame HDMI lalu dilaporkan sukses. Yang boleh
    // adalah degradasi mode secara TERBUKA setelah kamera benar-benar hilang,
    // supaya sesi pelanggan tidak mati — dan itu dilaporkan lewat heartbeat.
    if (_mode == CaptureMode.windowsSony) {
      final helper = SonyCameraHelperClient.instance;

      if (!_ptpReady || !helper.isCameraConnected) {
        debugPrint('🔄 [Capture] Sesi kamera Sony tidak aktif — menyiapkan ulang...');
        await ensureShutterPath();
      }

      if (_ptpReady) {
        for (var attempt = 1; attempt <= 2; attempt++) {
          final shot = await helper.capture();
          if (shot != null) {
            debugPrint('📸 [Capture] ✅ SUMBER = SHUTTER SONY (helper), '
                '${shot.dimensionLabel}');
            return CaptureOutcome(
              success: true,
              source: CaptureSource.sonyRemote,
              file: shot.file,
            );
          }
          if (attempt == 1) {
            debugPrint('🔁 [Capture] Percobaan shutter Sony ke-2...');
            // Sesi bisa basi setelah kamera tidur; bangun ulang lalu coba lagi.
            if (!helper.isCameraConnected) {
              _ptpReady = await helper.connectCamera();
              if (!_ptpReady) break;
            }
          }
        }
      }

      // Sampai di sini shutter Sony gagal. Bedakan dua situasi:
      //   - kamera masih ada tapi jepretan gagal (mis. AF tidak mengunci)
      //     → JANGAN degradasi, cukup laporkan gagal; tamu menekan lagi.
      //   - kamera/helper benar-benar hilang → degradasi supaya sesi jalan terus.
      final cameraGone = !helper.isProcessRunning ||
          !helper.isSocketOpen ||
          !helper.isCameraConnected;

      if (cameraGone && _uvcReady) {
        _degradeTo(
          CaptureMode.windowsCamera,
          'kamera Sony tidak terjangkau: ${helper.lastError}',
        );
        return CaptureOutcome(
          success: false,
          source: CaptureSource.sonyRemote,
          message: 'Kamera utama terputus. Sesi dilanjutkan dengan kualitas '
              'lebih rendah — silakan tekan jepret lagi.',
        );
      }

      if (cameraGone && !_uvcReady) {
        // Tidak ada apa pun untuk didegradasikan: capture card tidak terpasang.
        // Katakan apa adanya, jangan berpura-pura sesi masih bisa berfoto.
        return CaptureOutcome(
          success: false,
          source: CaptureSource.sonyRemote,
          message: 'Kamera tidak terhubung. Periksa kabel USB kamera, lalu '
              'coba lagi.',
        );
      }

      return CaptureOutcome(
        success: false,
        source: CaptureSource.sonyRemote,
        message: _sonyFailureMessage(helper.lastError),
      );
    }

    // ── MODE HYBRID / PTP-ONLY: Sony PTP adalah SATU-SATUNYA sumber foto ──
    //
    // TIDAK ADA fallback diam-diam ke frame HDMI di sini. Sebelumnya, kegagalan
    // PTP diam-diam diganti frame-grab 1080p dan tetap dilaporkan "sukses" —
    // hasil akhir turun dari 24 MP ke ~2 MP tanpa siapa pun tahu. Kegagalan
    // sekarang dilaporkan sebagai kegagalan.
    if (_mode == CaptureMode.hybrid || _mode == CaptureMode.ptpOnly) {
      // Sesi PTP bisa hilang kapan saja — perangkat USB yang re-enumerate
      // (nomor device berubah, izin USB hilang) membuat sesi lama tidak valid.
      // Jangan menyerah permanen: coba bangun ulang sekali di sini, supaya
      // tamu cukup menekan jepret lagi tanpa harus keluar-masuk halaman.
      if (!_ptpReady) {
        debugPrint('🔄 [Capture] Sesi PTP tidak aktif — mencoba menyiapkan ulang...');
        await ensureShutterPath();
      }

      if (!_ptpReady) {
        debugPrint('❌ [Capture] Jalur shutter PTP belum siap — capture DIBATALKAN.');
        debugPrint('   Mode $_mode mewajibkan foto berasal dari sensor Sony.');
        return const CaptureOutcome(
          success: false,
          source: CaptureSource.ptp,
          message: 'Kamera Sony belum siap. Periksa kabel USB-C dan '
              'pastikan USB Connection = PC Remote.',
        );
      }

      // Dua percobaan: shutter PTP sesekali gagal karena sesi basi.
      for (var attempt = 1; attempt <= 2; attempt++) {
        final outcome = await _capturePtpOnce(attempt);
        if (outcome != null) return outcome;
        if (attempt == 1) {
          debugPrint('🔁 [Capture] Percobaan shutter PTP ke-2...');
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
      }

      debugPrint('❌ [Capture] Shutter PTP gagal setelah 2 percobaan. '
          'TIDAK memakai frame HDMI sebagai foto final.');
      return const CaptureOutcome(
        success: false,
        source: CaptureSource.ptp,
        message: 'Gagal mengambil foto dari kamera Sony. Silakan coba lagi.',
      );
    }

    // ── MODE HDMI-ONLY: frame-grab memang satu-satunya sumber yang ada ──
    if (_mode == CaptureMode.hdmiOnly && UvcCameraService.instance.isOpen) {
      final f = await UvcCameraService.instance.takePhoto();
      if (f != null) {
        debugPrint('📸 [Capture] SUMBER = FRAME-GRAB HDMI (mode hdmiOnly, ~2 MP)');
        debugPrint('           file: ${f.path} '
            '(${(f.lengthSync() / 1048576).toStringAsFixed(2)} MB)');
        return CaptureOutcome(success: true, source: CaptureSource.uvc, file: f);
      }
      debugPrint('❌ [Capture] Frame-grab HDMI gagal: '
          '${UvcCameraService.instance.lastError}');
      return const CaptureOutcome(
        success: false,
        source: CaptureSource.uvc,
        message: 'Gagal mengambil gambar dari HDMI.',
      );
    }

    // ── MODE WINDOWS-CAMERA: diserahkan ke layar ──
    //
    // Layar kamera sudah memegang CameraController-nya sendiri untuk preview,
    // jadi jepretan diambil di sana lewat takePicture(). Menduplikasi
    // controller di service hanya akan membuat dua pemilik untuk satu
    // perangkat — sumber bug klasik pada kamera.
    if (_mode == CaptureMode.windowsCamera) {
      return const CaptureOutcome(
        success: false,
        source: CaptureSource.tablet,
        message: 'Jepretan diambil oleh layar lewat CameraController.',
      );
    }

    // ── MODE TABLET-ONLY: serahkan ke pemanggil ──
    return const CaptureOutcome(
      success: false,
      source: CaptureSource.tablet,
      message: 'Tidak ada kamera eksternal — memakai kamera tablet.',
    );
  }

  /// Terjemahkan kode error helper jadi kalimat yang berguna di layar kiosk.
  static String _sonyFailureMessage(String rawError) {
    if (rawError.startsWith('af_timeout') || rawError.startsWith('af_failed')) {
      return 'Kamera tidak berhasil mengunci fokus. Coba mundur sedikit atau '
          'tambah cahaya, lalu tekan jepret lagi.';
    }
    if (rawError.startsWith('capture_timeout')) {
      return 'Kamera tidak merespons jepretan. Silakan coba lagi.';
    }
    if (rawError.startsWith('unexpected_format')) {
      return 'Setelan format berkas kamera tidak sesuai (harus JPEG). '
          'Hubungi operator.';
    }
    if (rawError.startsWith('write_failed')) {
      return 'Gagal menyimpan foto ke penyimpanan. Hubungi operator.';
    }
    return 'Gagal mengambil foto dari kamera. Silakan coba lagi.';
  }

  /// Satu kali percobaan shutter PTP, lengkap dengan validasi berlapis.
  ///
  /// Mengembalikan null bila gagal (agar pemanggil bisa mencoba lagi).
  Future<CaptureOutcome?> _capturePtpOnce(int attempt) async {
    try {
      final res = await SonyPtpCameraService.capturePhoto().timeout(
        const Duration(seconds: 25),
        onTimeout: () => const SonyCaptureResult(
          isSuccess: false,
          message: 'Timeout menunggu shutter & transfer PTP (25 detik).',
        ),
      );

      // Validasi 1: native melaporkan sukses
      if (!res.isSuccess || res.filePath == null) {
        debugPrint('❌ [Capture] Percobaan $attempt gagal: ${res.message}');
        return null;
      }

      // Validasi 2: file benar-benar ada dan tidak kosong
      final f = File(res.filePath!);
      if (!f.existsSync()) {
        debugPrint('❌ [Capture] Percobaan $attempt: file tidak ada (${res.filePath})');
        return null;
      }
      final bytes = f.lengthSync();
      if (bytes <= 0) {
        debugPrint('❌ [Capture] Percobaan $attempt: file kosong (0 byte)');
        return null;
      }

      // Validasi 3: resolusi harus setara sensor, bukan frame HDMI
      if (!res.looksLikeSensorPhoto) {
        debugPrint('❌ [Capture] Percobaan $attempt: resolusi ${res.dimensionLabel} '
            'setara frame HDMI — ditolak, bukan foto sensor.');
        return null;
      }

      debugPrint('📸 [Capture] ✅ SUMBER = SHUTTER PTP (sensor Sony)');
      debugPrint('           resolusi: ${res.dimensionLabel}');
      debugPrint('           ukuran  : ${(bytes / 1048576).toStringAsFixed(2)} MB');
      debugPrint('           file    : ${res.filePath}');
      return CaptureOutcome(success: true, source: CaptureSource.ptp, file: f);
    } catch (e) {
      debugPrint('❌ [Capture] Percobaan $attempt error: $e');
      return null;
    }
  }


  /// Lepaskan sesi PTP.
  ///
  /// JANGAN dipanggil saat berpindah halaman kamera. Membuka ulang sesi PTP
  /// mengharuskan stream HDMI dihentikan lagi (lihat
  /// [prepareShutterPathWithUvcPaused]) — memutusnya di setiap dispose berarti
  /// kedipan preview di setiap perpindahan layar, dan berisiko gagal.
  /// Sesi sengaja dibiarkan hidup selama aplikasi berjalan.
  ///
  /// Kamera UVC juga TIDAK ditutup di sini: controller-nya singleton dan
  /// dipakai bersama semua layar. Siklus hidup view UVC ditangani oleh widget
  /// `UvcPreview`.
  Future<void> releasePtp() async {
    try {
      if (Platform.isWindows) {
        await SonyCameraHelperClient.instance.disconnectCamera();
      } else if (_ptpReady) {
        await SonyPtpCameraService.disconnect();
      }
    } catch (_) {}
    _ptpReady = false;
    _shutterFuture = null;
  }

  /// Matikan helper kamera. Dipanggil sekali saat aplikasi ditutup, bukan saat
  /// berpindah halaman — menjalankan ulang helper dan membuka sesi kamera
  /// memakan beberapa detik.
  Future<void> shutdownHelper() async {
    if (!Platform.isWindows) return;
    await SonyCameraHelperClient.instance.stop();
    _ptpReady = false;
  }
}
