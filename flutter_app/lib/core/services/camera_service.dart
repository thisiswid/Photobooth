import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'error_logger.dart';

/// CameraService helper untuk mendeteksi kamera eksternal (Sony ZV-E10 via UVC / Capture Card)
/// atau fallback ke kamera depan/belakang tablet.
///
/// Mendukung:
/// - Deteksi otomatis semua kamera (built-in + eksternal UVC/Capture Card)
/// - Pemilihan kamera manual oleh operator (persistent via FlutterSecureStorage)
/// - Auto-prioritas kamera eksternal (configurable)
/// - Live preview & test capture
class CameraService {
  CameraService._();

  // ─── Persistent Storage ─────────────────────────────────────────────────────
  static const _storage = FlutterSecureStorage();
  static const _selectedCameraKey = 'camera_selected_name';
  static const _autoSelectExternalKey = 'camera_auto_select_external';

  // ─── In-memory State ────────────────────────────────────────────────────────
  static CameraDescription? _selectedCamera;
  static bool _autoSelectExternal = true;
  static bool _preferencesLoaded = false;

  /// Kamera yang dipilih manual oleh operator di menu pengaturan (jika ada)
  static CameraDescription? get selectedCamera => _selectedCamera;

  /// Apakah auto-prioritas kamera eksternal diaktifkan
  static bool get autoSelectExternal => _autoSelectExternal;

  static void setSelectedCamera(CameraDescription? camera) {
    _selectedCamera = camera;
  }

  // ─── Persistence Methods ────────────────────────────────────────────────────

  /// Menyimpan pilihan kamera operator ke storage (persistent antar restart)
  static Future<void> saveSelectedCamera(String cameraName) async {
    try {
      await _storage.write(key: _selectedCameraKey, value: cameraName);
      debugPrint('💾 [CameraService] Pilihan kamera disimpan: $cameraName');
    } catch (e) {
      debugPrint('⚠️ [CameraService] Gagal menyimpan pilihan kamera: $e');
    }
  }

  /// Menghapus pilihan kamera manual — kembali ke mode auto-detect
  static Future<void> clearSelectedCamera() async {
    _selectedCamera = null;
    try {
      await _storage.delete(key: _selectedCameraKey);
      debugPrint('🔄 [CameraService] Pilihan kamera direset ke Auto-Detect');
    } catch (e) {
      debugPrint('⚠️ [CameraService] Gagal menghapus pilihan kamera: $e');
    }
  }

  /// Menyimpan pengaturan auto-select kamera eksternal
  static Future<void> saveAutoSelectExternal(bool value) async {
    _autoSelectExternal = value;
    try {
      await _storage.write(key: _autoSelectExternalKey, value: value.toString());
      debugPrint('💾 [CameraService] Auto-select eksternal: $value');
    } catch (e) {
      debugPrint('⚠️ [CameraService] Gagal menyimpan setting auto-select: $e');
    }
  }

  /// Memuat preferensi kamera yang tersimpan dari storage.
  /// Dipanggil saat app boot atau saat masuk settings untuk sinkronisasi.
  static Future<void> loadSavedPreference() async {
    if (_preferencesLoaded) return;

    try {
      // Load auto-select external setting
      final autoSelectStr = await _storage.read(key: _autoSelectExternalKey);
      if (autoSelectStr != null) {
        _autoSelectExternal = autoSelectStr.toLowerCase() == 'true';
      }

      // Load saved camera name & match with available cameras
      final savedName = await _storage.read(key: _selectedCameraKey);
      if (savedName != null && savedName.isNotEmpty) {
        final cameras = await availableCameras();
        final match = cameras.where((c) => c.name == savedName);
        if (match.isNotEmpty) {
          _selectedCamera = match.first;
          debugPrint('✅ [CameraService] Loaded saved camera: ${match.first.name}');
        } else {
          debugPrint('⚠️ [CameraService] Saved camera "$savedName" tidak ditemukan di perangkat saat ini.');
        }
      }

      _preferencesLoaded = true;
    } catch (e) {
      debugPrint('⚠️ [CameraService] Gagal memuat preferensi kamera: $e');
    }
  }

  // ─── Camera Detection ───────────────────────────────────────────────────────

  /// Mendapatkan semua kamera yang terdeteksi di perangkat
  static Future<List<CameraDescription>> getAvailableCamerasList() async {
    try {
      return await availableCameras();
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal membaca daftar kamera: $e',
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Mengidentifikasi jenis kamera (Eksternal Sony/Capture Card, Depan, Belakang, dll.)
  static String getCameraTypeLabel(CameraDescription cam) {
    final lowerName = cam.name.toLowerCase();
    final sonyKeywords = ['sony', 'zv-e10', 'zve10', 'cam link', 'camlink', 'uvc', 'usb video', 'capture', 'external', 'hdmi'];
    
    if (sonyKeywords.any((kw) => lowerName.contains(kw))) {
      return 'Kamera Eksternal / Sony ZV-E10 (Capture Card)';
    }
    if (cam.lensDirection == CameraLensDirection.external) {
      return 'Kamera Eksternal USB (UVC)';
    }
    if (cam.lensDirection == CameraLensDirection.front) {
      return 'Kamera Depan Tablet (Front)';
    }
    if (cam.lensDirection == CameraLensDirection.back) {
      return 'Kamera Belakang Tablet (Back)';
    }
    return 'Kamera Sistem / Default';
  }

  /// Mengetahui apakah kamera adalah eksternal (Sony / Capture Card / UVC)
  static bool isExternalCamera(CameraDescription cam) {
    final lowerName = cam.name.toLowerCase();
    final sonyKeywords = ['sony', 'zv-e10', 'zve10', 'cam link', 'camlink', 'uvc', 'usb video', 'capture', 'external', 'hdmi'];
    return cam.lensDirection == CameraLensDirection.external ||
        sonyKeywords.any((kw) => lowerName.contains(kw));
  }

  /// Mendapatkan label arah lensa yang human-readable
  static String getCameraDirectionLabel(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return 'Depan (Front)';
      case CameraLensDirection.back:
        return 'Belakang (Back)';
      case CameraLensDirection.external:
        return 'Eksternal (USB/UVC)';
    }
  }

  /// Mendapatkan label resolusi yang human-readable
  static String getResolutionLabel(ResolutionPreset preset) {
    switch (preset) {
      case ResolutionPreset.low:
        return '240p (Low)';
      case ResolutionPreset.medium:
        return '480p (Medium)';
      case ResolutionPreset.high:
        return '720p (High)';
      case ResolutionPreset.veryHigh:
        return '1080p (Very High)';
      case ResolutionPreset.ultraHigh:
        return '2160p / 4K (Ultra High)';
      case ResolutionPreset.max:
        return 'Resolusi Maksimum';
    }
  }

  // ─── Camera Selection Logic ─────────────────────────────────────────────────

  /// Mendeteksi kamera terbaik yang tersedia:
  /// 1. Prioritas kamera yang dipilih manual oleh operator (dari storage)
  /// 2. Prioritas kamera eksternal (UVC / USB Capture Card / Sony ZV-E10) — jika auto-select aktif
  /// 3. Kamera depan tablet (front)
  /// 4. Kamera belakang / kamera pertama yang ditemukan
  static Future<CameraDescription?> getBestCamera() async {
    // Pastikan preferensi sudah dimuat
    await loadSavedPreference();

    // 0. Kamera yang dipilih manual oleh operator
    if (_selectedCamera != null) {
      return _selectedCamera;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ErrorLogger.instance.logCameraError(
          message: 'Tidak ada perangkat kamera yang terdeteksi di sistem.',
        );
        return null;
      }

      debugPrint('📸 Kamera terdeteksi (${cameras.length}):');
      for (final cam in cameras) {
        debugPrint(' - ${cam.name} (${cam.lensDirection}) -> ${getCameraTypeLabel(cam)}');
      }

      // 1. Jika auto-select eksternal aktif, cek prioritas keyword Sony / Capture Card
      if (_autoSelectExternal) {
        final sonyKeywords = ['sony', 'zv-e10', 'zve10', 'cam link', 'camlink', 'uvc', 'usb video', 'capture', 'external', 'hdmi'];
        for (final cam in cameras) {
          final lowerName = cam.name.toLowerCase();
          if (sonyKeywords.any((kw) => lowerName.contains(kw))) {
            debugPrint('✅ [CameraService] Menggunakan kamera Sony/Capture Card: ${cam.name} (${cam.lensDirection})');
            return cam;
          }
        }

        // 2. Cek kamera eksternal (USB / UVC standard)
        final externalCam = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.external,
        );
        if (externalCam.isNotEmpty) {
          debugPrint('✅ [CameraService] Menggunakan kamera eksternal: ${externalCam.first.name}');
          return externalCam.first;
        }
      }

      // 3. Cek kamera depan
      final frontCam = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontCam.isNotEmpty) {
        debugPrint('ℹ️ [CameraService] Fallback kamera depan: ${frontCam.first.name}');
        return frontCam.first;
      }

      // 4. Fallback ke kamera pertama yang ada
      debugPrint('ℹ️ [CameraService] Fallback kamera default: ${cameras.first.name}');
      return cameras.first;
    } catch (e, stack) {
      ErrorLogger.instance.logCameraError(
        message: 'Gagal mendeteksi kamera: $e',
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Membuat controller kamera dengan resolusi tinggi yang optimal untuk photobooth
  static Future<CameraController?> createController({
    ResolutionPreset resolution = ResolutionPreset.high,
    bool enableAudio = false,
    CameraDescription? customCamera,
  }) async {
    final camera = customCamera ?? await getBestCamera();
    if (camera == null) return null;

    final controller = CameraController(
      camera,
      resolution,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    return controller;
  }
}
