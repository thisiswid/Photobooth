import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'error_logger.dart';

/// CameraService helper untuk mendeteksi kamera eksternal (Sony ZV-E10 via UVC / Capture Card)
/// atau fallback ke kamera depan/belakang tablet.
class CameraService {
  CameraService._();

  /// Mendeteksi kamera terbaik yang tersedia:
  /// 1. Prioritas kamera eksternal (UVC / USB Capture Card / Sony ZV-E10)
  /// 2. Kamera depan tablet (front)
  /// 3. Kamera belakang / kamera pertama yang ditemukan
  static Future<CameraDescription?> getBestCamera() async {
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
        debugPrint(' - ${cam.name} (${cam.lensDirection})');
      }

      // 1. Cek kamera eksternal (USB / UVC / Capture Card)
      final externalCam = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.external,
      );
      if (externalCam.isNotEmpty) {
        debugPrint('✅ Menggunakan kamera eksternal: ${externalCam.first.name}');
        return externalCam.first;
      }

      // 2. Cek kamera depan
      final frontCam = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontCam.isNotEmpty) {
        debugPrint('ℹ️ Menggunakan kamera depan: ${frontCam.first.name}');
        return frontCam.first;
      }

      // 3. Fallback
      debugPrint('ℹ️ Menggunakan kamera default: ${cameras.first.name}');
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
  }) async {
    final camera = await getBestCamera();
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
