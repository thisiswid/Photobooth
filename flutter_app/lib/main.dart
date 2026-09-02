import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/constants/app_constants.dart';
import 'core/services/heartbeat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _setupKioskDisplay();

  // Initialize DioClient (dev mode for now)
  DioClient.instance.initialize(isProduction: false);

  // Start background heartbeat telemetry
  HeartbeatService.instance.start();

  runApp(
    const ProviderScope(
      child: SnapTechBoothApp(),
    ),
  );
}

/// Menyiapkan tampilan kiosk sesuai platform.
///
/// Android : orientasi bebas + immersive sticky lewat SystemChrome.
/// Windows : SystemChrome.setEnabledSystemUIMode TIDAK MELAKUKAN APA PUN di
///           desktop. Fullscreen harus lewat window_manager, kalau tidak
///           jendela tetap punya title bar dan taskbar tetap terlihat.
Future<void> _setupKioskDisplay() async {
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      fullScreen: true,
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
    return;
  }

  // Jalur Android — perilakunya sengaja dibiarkan persis seperti sebelumnya.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class SnapTechBoothApp extends ConsumerWidget {
  const SnapTechBoothApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      // Design canvas: adapts to orientation (landscape 1280x800, portrait 800x1280)
      designSize: const Size(1280, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
