import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientation for kiosk experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full-screen immersive kiosk mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize DioClient (dev mode for now)
  DioClient.instance.initialize(isProduction: false);

  runApp(
    const ProviderScope(
      child: FakultasKopiApp(),
    ),
  );
}

class FakultasKopiApp extends ConsumerWidget {
  const FakultasKopiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      // Design canvas: 1280x800 (landscape tablet reference)
      designSize: const Size(
        AppConstants.designWidth,
        AppConstants.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) {
            // Prevent text scaling from OS accessibility settings
            // to keep kiosk layout consistent
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
