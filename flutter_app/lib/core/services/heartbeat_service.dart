import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import 'camera_service.dart';
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
    try {
      final deviceKey = await ProvisioningService.instance.getDeviceKey();
      if (deviceKey == null || deviceKey.trim().isEmpty) {
        // Belum di-pair, lewati
        return;
      }

      // Cek status hardware terkini
      String printerStatus = 'ready';
      try {
        final isPrinterOk = await PrinterService.isPrinterReachable();
        printerStatus = isPrinterOk ? 'ready' : 'offline';
      } catch (_) {
        printerStatus = 'error';
      }

      String cameraStatus = 'connected';
      try {
        final cameras = await CameraService.getAvailableCamerasList();
        cameraStatus = cameras.isNotEmpty ? 'connected' : 'disconnected';
      } catch (_) {
        cameraStatus = 'error';
      }

      await DioClient.instance.safeRequest(
        () => DioClient.instance.dio.post(
          ApiEndpoints.deviceHeartbeat,
          data: {
            'device_key': deviceKey.trim(),
            'printer_status': printerStatus,
            'camera_status': cameraStatus,
            'app_version': AppConstants.appVersion,
          },
        ),
      );

      debugPrint('💓 Heartbeat sent: Key=$deviceKey, Printer=$printerStatus, Camera=$cameraStatus');
    } catch (e) {
      debugPrint('⚠️ Heartbeat delivery failed: $e');
    }
  }
}
