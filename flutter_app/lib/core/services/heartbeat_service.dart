import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import 'camera_service.dart';
import 'photobooth_capture_service.dart';
import 'printer_service.dart';
import 'provisioning_service.dart';

/// Background Heartbeat Service untuk mengirim telemetri status kiosk & hardware ke server.
class HeartbeatService {
  HeartbeatService._();
  static final HeartbeatService instance = HeartbeatService._();

  Timer? _timer;
  bool _isRunning = false;

  /// Memulai pengiriman heartbeat periodik (tiap 60 detik)
  void start({Duration interval = const Duration(seconds: 60)}) {
    if (_isRunning) return;
    _isRunning = true;

    // Kirim heartbeat pertama kali setelah 5 detik
    Future.delayed(const Duration(seconds: 5), () {
      if (_isRunning) sendHeartbeat();
    });

    _timer = Timer.periodic(interval, (_) {
      sendHeartbeat();
    });
    debugPrint('💓 HeartbeatService started (interval: ${interval.inSeconds}s)');
  }

  /// Menghentikan pengiriman heartbeat
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('⏹️ HeartbeatService stopped');
  }

  /// Mengirim payload telemetri heartbeat satu kali
  Future<void> sendHeartbeat() async {
    // Pengukuran sementara (C-perf): heartbeat memanggil dua hal yang MAHAL di
    // Windows — PowerShell/CIM untuk status printer dan enumerasi Media
    // Foundation untuk daftar kamera. Keduanya berjalan tiap 60 detik tanpa
    // melihat apakah pelanggan sedang berpose. Angka-angka ini dipakai untuk
    // membuktikan (atau membantah) dugaan itu, bukan tebakan.
    final sw = Stopwatch()..start();
    try {
      final deviceKey = await ProvisioningService.instance.getDeviceKey();
      if (deviceKey == null || deviceKey.trim().isEmpty) {
        // Belum di-pair, lewati
        return;
      }

      // Cek status hardware terkini
      // Status printer sesungguhnya. Di Windows ini membedakan kertas habis,
      // tinta habis, dan macet — bukan sekadar hidup/mati seperti di Android.
      String printerStatus = 'unknown';
      final tPrinter = sw.elapsedMilliseconds;
      try {
        printerStatus = await PrinterService.getHealthCode();
      } catch (_) {
        printerStatus = 'error';
      }
      final dPrinter = sw.elapsedMilliseconds - tPrinter;

      String cameraStatus = 'connected';
      final tCamera = sw.elapsedMilliseconds;
      try {
        final cameras = await CameraService.getAvailableCamerasList();
        cameraStatus = cameras.isNotEmpty ? 'connected' : 'disconnected';
      } catch (_) {
        cameraStatus = 'error';
      }
      final dCamera = sw.elapsedMilliseconds - tCamera;
      debugPrint('💓 [Perf] heartbeat — status printer $dPrinter ms, '
          'daftar kamera $dCamera ms (mulai +$tPrinter ms)');

      // Jalur kamera yang SEDANG dipakai. Saat terdegradasi nilainya berbentuk
      // `windowsCamera(from:windowsSony)`, sehingga penurunan kualitas foto
      // terlihat dari dasbor tanpa perlu ada yang memeriksa kiosk langsung.
      final capture = PhotoboothCaptureService.instance;
      final captureMode = capture.heartbeatCaptureMode;

      final tPost = sw.elapsedMilliseconds;
      await DioClient.instance.safeRequest(
        () => DioClient.instance.dio.post(
          ApiEndpoints.deviceHeartbeat,
          data: {
            'device_key': deviceKey.trim(),
            'printer_status': printerStatus,
            'camera_status': cameraStatus,
            'app_version': AppConstants.appVersion,
            'capture_mode': captureMode,
            'capture_degraded': capture.isDegraded,
            if (capture.isDegraded) 'capture_degraded_reason': capture.degradedReason,
          },
        ),
      );

      debugPrint('💓 [Perf] heartbeat — POST ${sw.elapsedMilliseconds - tPost} ms, '
          'total ${sw.elapsedMilliseconds} ms');
      debugPrint('💓 Heartbeat sent: Key=$deviceKey, Printer=$printerStatus, '
          'Camera=$cameraStatus, Capture=$captureMode');
      if (capture.isDegraded) {
        debugPrint('   ⬇️ TERDEGRADASI: ${capture.degradedReason}');
      }
    } catch (e) {
      debugPrint('⚠️ Heartbeat delivery failed: $e');
    }
  }
}
