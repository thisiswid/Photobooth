import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status koneksi kamera Sony ZV-E10 / USB HDMI Capture Card via USB Host
class SonyCameraStatus {
  final bool isDetected;
  final bool hasPermission;
  final bool isConnected;
  final bool isUvc;
  final String? productName;
  final int? vendorId;
  final int? productId;
  final String? devicePath;
  final String? serialNumber;
  final int totalUsbDevices;

  // ── Hybrid: dua perangkat terpisah ────────────────────────────────────────
  /// HDMI capture card terdeteksi (jalur LIVE PREVIEW).
  final bool uvcDetected;
  final bool uvcHasPermission;
  final String? uvcProductName;

  /// Kamera Sony via kabel C-to-C terdeteksi (jalur SHUTTER / foto resolusi penuh).
  final bool ptpDetected;
  final bool ptpHasPermission;
  final String? ptpProductName;
  final bool ptpSessionOpen;
  final bool isSony;
  final int androidSdkInt;

  /// Kedua jalur tersedia — mode hybrid penuh bisa dipakai.
  bool get isHybridReady => uvcDetected && ptpDetected;

  const SonyCameraStatus({
    required this.isDetected,
    required this.hasPermission,
    required this.isConnected,
    this.isUvc = false,
    this.productName,
    this.vendorId,
    this.productId,
    this.devicePath,
    this.serialNumber,
    this.totalUsbDevices = 0,
    this.uvcDetected = false,
    this.uvcHasPermission = false,
    this.uvcProductName,
    this.ptpDetected = false,
    this.ptpHasPermission = false,
    this.ptpProductName,
    this.ptpSessionOpen = false,
    this.isSony = false,
    this.androidSdkInt = 0,
  });

  factory SonyCameraStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SonyCameraStatus(
        isDetected: false,
        hasPermission: false,
        isConnected: false,
        isUvc: false,
      );
    }
    return SonyCameraStatus(
      isDetected: map['isDetected'] == true,
      hasPermission: map['hasPermission'] == true,
      isConnected: map['isConnected'] == true,
      isUvc: map['isUvc'] == true,
      productName: map['productName'] as String?,
      vendorId: map['vendorId'] as int?,
      productId: map['productId'] as int?,
      devicePath: map['devicePath'] as String?,
      serialNumber: map['serialNumber'] as String?,
      totalUsbDevices: (map['totalUsbDevices'] as num?)?.toInt() ?? 0,
      uvcDetected: map['uvcDetected'] == true,
      uvcHasPermission: map['uvcHasPermission'] == true,
      uvcProductName: map['uvcProductName'] as String?,
      ptpDetected: map['ptpDetected'] == true,
      ptpHasPermission: map['ptpHasPermission'] == true,
      ptpProductName: map['ptpProductName'] as String?,
      ptpSessionOpen: map['ptpSessionOpen'] == true,
      isSony: map['isSony'] == true,
      androidSdkInt: (map['androidSdkInt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Hasil dari perintah remote capture Sony ZV-E10 via PTP
class SonyCaptureResult {
  final bool isSuccess;
  final String? filePath;
  final int fileSizeBytes;
  final String message;

  /// Dimensi asli JPEG yang diunduh dari kamera.
  ///
  /// Ini bukti bahwa foto berasal dari sensor Sony (mis. 6000x4000) dan bukan
  /// frame HDMI 1920x1080. "Shutter berhasil" tidak sama dengan "foto
  /// resolusi penuh berhasil diunduh".
  final int width;
  final int height;

  const SonyCaptureResult({
    required this.isSuccess,
    this.filePath,
    this.fileSizeBytes = 0,
    required this.message,
    this.width = 0,
    this.height = 0,
  });

  double get megapixels => (width * height) / 1000000;

  /// Foto sensor Sony selalu jauh di atas 1920x1080.
  bool get looksLikeSensorPhoto => width > 1920 || height > 1080;

  String get dimensionLabel =>
      width > 0 ? '${width}x$height (${megapixels.toStringAsFixed(1)} MP)' : 'dimensi tidak diketahui';

  factory SonyCaptureResult.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SonyCaptureResult(
        isSuccess: false,
        message: 'Respon capture kosong dari sistem native.',
      );
    }
    return SonyCaptureResult(
      isSuccess: map['success'] == true,
      filePath: map['filePath'] as String?,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      message: map['message'] as String? ?? '',
    );
  }
}

/// SonyPtpCameraService
///
/// Service Flutter untuk berkomunikasi dengan driver Native Android PTP
/// (`SonyPtpCameraManager`) via MethodChannel `'com.fakultaskopi.photobooth/sony_camera'`.
class SonyPtpCameraService {
  SonyPtpCameraService._();

  static const _channel = MethodChannel('com.fakultaskopi.photobooth/sony_camera');

  /// Mendapatkan status terkini deteksi Sony ZV-E10 di USB Host Android
  static Future<SonyCameraStatus> getStatus() async {
    if (!Platform.isAndroid) {
      return const SonyCameraStatus(
        isDetected: false,
        hasPermission: false,
        isConnected: false,
      );
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSonyCameraStatus');
      return SonyCameraStatus.fromMap(res);
    } catch (e) {
      debugPrint('⚠️ [SonyPtpCameraService] getStatus error: $e');
      return const SonyCameraStatus(
        isDetected: false,
        hasPermission: false,
        isConnected: false,
      );
    }
  }

  /// Meminta izin akses USB untuk HDMI capture card (jalur live preview UVC)
  static Future<bool> requestUvcPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestUvcPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('⚠️ [SonyPtpCameraService] requestUvcPermission error: $e');
      return false;
    }
  }

  /// Meminta izin akses USB (USB Permission Dialog) ke user Android
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestSonyPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('⚠️ [SonyPtpCameraService] requestPermission error: $e');
      return false;
    }
  }

  /// Membuka koneksi USB PTP dan melakukan handshake Sony SDIO Connect
  static Future<bool> connect() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('connectSonyCamera');
      return res?['success'] == true;
    } catch (e) {
      debugPrint('⚠️ [SonyPtpCameraService] connect error: $e');
      return false;
    }
  }

  /// Menutup koneksi USB PTP
  static Future<void> disconnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disconnectSonyCamera');
    } catch (e) {
      debugPrint('⚠️ [SonyPtpCameraService] disconnect error: $e');
    }
  }

  /// Memicu Shutter Capture fisik pada Sony ZV-E10 dan mendownload file JPEG hasilnya
  static Future<SonyCaptureResult> capturePhoto() async {
    if (!Platform.isAndroid) {
      return const SonyCaptureResult(
        isSuccess: false,
        message: 'Sony PTP Camera hanya didukung pada perangkat Android.',
      );
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('captureSonyPhoto');
      return SonyCaptureResult.fromMap(res);
    } catch (e) {
      debugPrint('❌ [SonyPtpCameraService] capturePhoto error: $e');
      return SonyCaptureResult(
        isSuccess: false,
        message: 'Gagal remote capture: $e',
      );
    }
  }
}
