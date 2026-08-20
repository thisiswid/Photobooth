/// Application-wide constants for Fakultas Kopi Photobooth.
/// All magic numbers and configuration values live here.
abstract final class AppConstants {
  // ── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'Fakultas Kopi Photobooth';
  static const String appVersion = '1.0.0';
  static const String brandName = 'FAKULTAS KOPI';
  static const String tagline = 'Capture Your Moment';

  // ── API Configuration ─────────────────────────────────────────────────────
  /// Production VPS base URL:
  /// Defaults to production domain `https://snaptechbooth.my.id/api`
  /// Can be overridden via --dart-define=API_BASE_URL=http://...
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    return 'https://snaptechbooth.my.id/api';
  }

  static String get apiBaseUrlDev => apiBaseUrl;
  static const String apiBaseUrlProd = 'https://snaptechbooth.my.id/api';
  static const String galleryBaseUrl = 'https://snaptechbooth.my.id';
  static const Duration apiConnectTimeout = Duration(seconds: 15);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);
  static const int apiMaxRetries = 3;

  // ── Storage & Result QR URLs ──────────────────────────────────────────────
  /// Storage Base URL for loading frames, filters, and uploaded images:
  static String get storageBaseUrl {
    return apiBaseUrl.replaceAll('/api', '/storage');
  }

  /// Base URL for customer result QR code: GET /d/{token}
  static String get resultBaseUrl {
    return apiBaseUrl.replaceAll('/api', '/d');
  }

  // ── Session ───────────────────────────────────────────────────────────────
  static const Duration sessionDuration = Duration(minutes: 6);
  static const Duration sessionWarningThreshold = Duration(minutes: 1);
  static const Duration qrExpiryDuration = Duration(days: 30);
  static const Duration sessionTransitionDelay = Duration(seconds: 3);
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
