import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/tutorial/presentation/tutorial_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/frame/presentation/frame_selection_screen.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/preview/presentation/photo_preview_screen.dart';
import '../../features/filter/presentation/filter_screen.dart';
import '../../features/result/presentation/final_result_screen.dart';
import '../../features/settings/presentation/device_settings_screen.dart';
import '../../features/provisioning/presentation/provisioning_screen.dart';
import '../../features/provisioning/providers/tenant_provider.dart';
import '../../features/session/providers/session_provider.dart';

part 'app_router.g.dart';

// ── Route paths ───────────────────────────────────────────────────────────────

/// Canonical flow:
/// provisioning (if setup) → welcome → tutorial → payment → frame → camera → preview → filter → result
abstract final class AppRoutes {
  static const provisioning   = '/provisioning';
  static const welcome        = '/';
  static const tutorial       = '/tutorial';
  static const payment        = '/payment';
  static const frame          = '/frame';
  static const camera         = '/camera';
  static const preview        = '/preview';
  static const filter         = '/filter';
  static const result         = '/result';
  static const deviceSettings = '/device-settings';
}

// ── Refresh notifier ──────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionNotifierProvider, (_, __) => notifyListeners());
    _ref.listen(tenantNotifierProvider, (_, __) => notifyListeners());
  }
  final AppRouterRef _ref;
}

// ── Router ────────────────────────────────────────────────────────────────────

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.welcome,
    debugLogDiagnostics: true,
    refreshListenable: notifier,

    redirect: (BuildContext context, GoRouterState state) {
      final location = state.matchedLocation;

      // Always allow setup/provisioning screen
      if (location == AppRoutes.provisioning) return null;

      // Open routes — no session required.
      const openRoutes = {AppRoutes.welcome, AppRoutes.tutorial, AppRoutes.payment, AppRoutes.deviceSettings};
      if (openRoutes.contains(location)) return null;

      final session = ref.read(sessionNotifierProvider);

      if (!session.hasActiveSession || !session.isPaid) return AppRoutes.welcome;
      if (session.isExpired) return AppRoutes.welcome;

      // Require frame selection before camera/preview/filter/result.
      const requiresFrame = {
        AppRoutes.camera,
        AppRoutes.preview,
        AppRoutes.filter,
        AppRoutes.result,
      };
      if (requiresFrame.contains(location) && session.session?.frameId == null) {
        return AppRoutes.frame;
      }

      return null;
    },

    routes: [
      GoRoute(path: AppRoutes.provisioning,   builder: (_, __) => const ProvisioningScreen()),
      GoRoute(path: AppRoutes.welcome,        builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.tutorial,       builder: (_, __) => const TutorialScreen()),
      GoRoute(path: AppRoutes.payment,        builder: (_, __) => const PaymentScreen()),
      GoRoute(path: AppRoutes.frame,          builder: (_, __) => const FrameSelectionScreen()),
      GoRoute(path: AppRoutes.camera,         builder: (_, __) => const CameraScreen()),
      GoRoute(path: AppRoutes.preview,        builder: (_, __) => const PhotoPreviewScreen()),
      GoRoute(path: AppRoutes.filter,         builder: (_, __) => const FilterScreen()),
      GoRoute(path: AppRoutes.result,         builder: (_, __) => const FinalResultScreen()),
      GoRoute(path: AppRoutes.deviceSettings, builder: (_, __) => const DeviceSettingsScreen()),
    ],

    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );
}

// ── Error page ────────────────────────────────────────────────────────────────

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F08),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC89B5B), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Halaman tidak ditemukan',
              style: TextStyle(color: Color(0xFFF8E9D2), fontSize: 24),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Color(0xFF997755), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.welcome),
              child: const Text('Kembali ke Awal'),
            ),
          ],
        ),
      ),
    );
  }
}
