import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Application-wide constants for Fakultas Kopi Photobooth.
/// All magic numbers and configuration values live here.
abstract final class AppConstants {
  // ── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'Fakultas Kopi Photobooth';
  static const String appVersion = '1.0.0';
  static const String brandName = 'FAKULTAS KOPI';
  static const String tagline = 'Capture Your Moment';

  // ── API Configuration ─────────────────────────────────────────────────────
  /// Dev base URL:
  /// - Windows / Desktop / Web → 127.0.0.1 (localhost)
  /// - Android Device / Emulator → IP lokal PC di WiFi (192.168.1.4) atau 10.0.2.2
  /// - Bisa di-override via: --dart-define=API_BASE_URL=http://...
  static String get apiBaseUrlDev {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    if (Platform.isAndroid) {
      // Menggunakan IP lokal WiFi PC saat ini (192.168.1.4)
      return 'http://192.168.1.4:8000/api';
    }

    // Windows Desktop, macOS, Linux
    return 'http://127.0.0.1:8000/api';
  }

  static const String apiBaseUrlProd = 'https://api.fakultaskopi.com/api';
  static const String galleryBaseUrl = 'https://gallery.fakultaskopi.com';
  static const Duration apiConnectTimeout = Duration(seconds: 15);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);
  static const int apiMaxRetries = 3;

  // ── Session ───────────────────────────────────────────────────────────────
  /// 5-minute session timer — starts at Start Session, after payment PAID.
  /// Timer is NOT active during Welcome, Tutorial, or Payment screens.
  static const Duration sessionDuration = Duration(minutes: 5);
  static const Duration sessionWarningThreshold = Duration(minutes: 1);
  static const Duration qrExpiryDuration = Duration(days: 30);
  static const Duration sessionTransitionDelay = Duration(seconds: 3);

  /// Base URL for customer result QR code: GET /d/{token}
  static String get resultBaseUrl {
    return apiBaseUrlDev.replaceAll('/api', '/d');
  }
  static const int sessionCodeLength = 8;

  // ── Camera ────────────────────────────────────────────────────────────────
  static const int countdownSeconds = 5;
  static const Duration shutterAnimationDuration = Duration(milliseconds: 300);
  static const Duration photoReviewDuration = Duration(seconds: 2);
  static const int maxPhotosPerSession = 10;
  static const double cameraAspectRatio16x9 = 16.0 / 9.0;
  static const double cameraAspectRatio4x3 = 4.0 / 3.0;

  // ── Printing ──────────────────────────────────────────────────────────────
  static const Duration printingStepDuration = Duration(seconds: 2);
  static const Duration printingTotalTimeout = Duration(seconds: 60);
  static const int defaultPrintCopies = 1;

  // ── Generation ───────────────────────────────────────────────────────────
  static const Duration generateStepDuration = Duration(seconds: 2);
  static const String stripFileName = 'strip.jpg';
  static const String gifFileName = 'animation.gif';

  // ── Storage ───────────────────────────────────────────────────────────────
  static const int maxUploadFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageMimes = ['image/jpeg', 'image/png'];
  static const String storageSessionsPrefix = 'sessions';

  // ── UI / Responsive ───────────────────────────────────────────────────────
  static const double designWidth = 1280.0;
  static const double designHeight = 800.0;
  static const double minTouchTarget = 64.0;  // px
  static const double smallTabletBreakpoint = 800.0;
  static const double largeTabletBreakpoint = 1200.0;
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;

  // ── Animation ─────────────────────────────────────────────────────────────
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 600);
  static const Duration animationVerySlow = Duration(milliseconds: 1000);

  // ── Local Storage Keys ────────────────────────────────────────────────────
  static const String hiveSessionBox = 'session_box';
  static const String hivePhotosBox = 'photos_box';
  static const String hiveSettingsBox = 'settings_box';
  static const String secureKeyAuthToken = 'auth_token';
  static const String secureKeyDeviceId = 'device_id';
  static const String prefSessionCode = 'current_session_code';
  static const String prefCurrentStep = 'current_step';
}
