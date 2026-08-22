/// All API endpoint paths for Fakultas Kopi Photobooth backend.
/// Used with DioClient.baseUrl as prefix.
abstract final class ApiEndpoints {
  // ── Device Provisioning & Telemetry ────────────────────────────────────────
  static const String deviceActivate = '/devices/activate';
  static String deviceConfig(String deviceKey) => '/devices/$deviceKey/config';
  static const String deviceHeartbeat = '/devices/heartbeat';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/login';
  static const String logout = '/admin/auth/logout';
  static const String me = '/admin/auth/me';

  // ── Session ───────────────────────────────────────────────────────────────
  static const String sessionCreate = '/session/create';

  static String sessionShow(String code) => '/session/$code';
  static String sessionUpdatePayment(String code) =>
      '/session/$code/payment';
  static String sessionFinalize(String code) => '/session/$code/finalize';

  // ── Photo ─────────────────────────────────────────────────────────────────
  static String photoUpload(String code) => '/session/$code/photo';
  static String photoIndex(String code) => '/session/$code/photos';
  static String photoDestroy(int id) => '/photo/$id';

  // ── Generate Result ───────────────────────────────────────────────────────
  static String generateResult(String code) => '/session/$code/generate';
  static String generateStatus(String jobId) => '/generate/$jobId/status';

  // ── Print ─────────────────────────────────────────────────────────────────
  static String printSession(String code) => '/session/$code/print';
  static String printStatus(int printId) => '/print/$printId/status';
  static String printRetry(int printId) => '/print/$printId/retry';

  // ── Gallery (Public) ──────────────────────────────────────────────────────
  static String gallery(String code) => '/gallery/$code';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminDashboard = '/admin/dashboard';
  static const String adminSessions = '/admin/sessions';
  static String adminSessionDelete(int id) => '/admin/session/$id';
  static String adminSessionReprint(int id) => '/admin/session/$id/reprint';

  // ── Templates ─────────────────────────────────────────────────────────────
  static const String frames = '/admin/frames';
  static const String stickers = '/admin/stickers';
  static const String layouts = '/admin/layouts';

  static String eventFrames(int eventId) => '/events/$eventId/frames';
  static String eventFilters(int eventId) => '/events/$eventId/filters';

  // ── Packages (public) ─────────────────────────────────────────────────────
  static const String packages = '/packages';
}
