import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:win32/win32.dart' as win32;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/constants/app_constants.dart';
import 'core/services/heartbeat_service.dart';
import 'core/services/provisioning_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mencegah monitor Windows / sistem sleep (Always ON Kiosk)
  _preventDisplaySleep();

  await _setupKioskDisplay();

  // Pastikan info device key & tenant config termuat sebelum router aktif
  await ProvisioningService.instance.warmUp();

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

/// Menjaga layar monitor dan sistem tetap menyala (mencegah sleep/screensaver)
void _preventDisplaySleep() {
  if (!kIsWeb && Platform.isWindows) {
    try {
      // ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
      // 0x80000000 | 0x00000001 | 0x00000002 = 0x80000003
      win32.SetThreadExecutionState(
        win32.ES_CONTINUOUS | win32.ES_SYSTEM_REQUIRED | win32.ES_DISPLAY_REQUIRED,
      );
      debugPrint('☀️ [Kiosk] Windows display sleep prevented (Always ON)');
    } catch (e) {
      debugPrint('⚠️ [Kiosk] Failed to set display execution state: $e');
    }
  }
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

    // Fullscreen tanpa title bar HANYA di build release (mesin kiosk).
    //
    // Di debug, jendela dibiarkan normal dan bisa dipindah/ditutup. Fullscreen
    // saat debug membuat aplikasi tampak "tidak terbuka" — jendelanya menutupi
    // seluruh layar tanpa title bar, sulit dibedakan dari aplikasi yang gagal
    // start, dan menyulitkan melihat log di terminal sebelah.
    const options = kReleaseMode
        ? WindowOptions(
            fullScreen: true,
            titleBarStyle: TitleBarStyle.hidden,
          )
        : WindowOptions(
            size: Size(1280, 800),
            center: true,
            title: 'SnapTechBooth (debug)',
            titleBarStyle: TitleBarStyle.normal,
          );

    await windowManager.waitUntilReadyToShow(options, () async {
      if (kReleaseMode) {
        await windowManager.setFullScreen(true);
      }
      await windowManager.show();
      await windowManager.focus();
    });

    // Tamu tidak boleh bisa menutup aplikasi.
    //
    // `Alt+F4` dan tombol tutup mengirim permintaan tutup ke jendela.
    // `setPreventClose(true)` membuat permintaan itu tidak langsung dijalankan,
    // lalu `KioskWindowGuard` menolaknya. Tanpa ini, satu penekanan tombol
    // menjatuhkan kiosk ke desktop Windows di tengah acara.
    //
    // HANYA di release. Saat debug jendela harus tetap bisa ditutup — mengunci
    // diri sendiri selama pengembangan itu menyiksa dan mudah terlupa.
    //
    // Ini menutup Alt+F4 saja. Tombol Windows dan Ctrl+Shift+Esc ditangani
    // sistem operasi, bukan aplikasi — keduanya butuh Shell Launcher atau
    // Group Policy (Windows 11 Pro), dan ada di checklist
    // docs/deployment-windows.md.
    if (kReleaseMode) {
      await windowManager.setPreventClose(true);
      windowManager.addListener(KioskWindowGuard());
    }
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
          theme: AppTheme.paper,
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


/// Menolak permintaan menutup jendela pada mesin kiosk.
///
/// Dipasang hanya di build release (lihat [_setupKioskDisplay]). Operator
/// menghentikan aplikasi lewat Hidden Settings atau Task Manager, bukan lewat
/// Alt+F4 — supaya tamu tidak bisa menjatuhkan kiosk ke desktop.
class KioskWindowGuard extends WindowListener {
  @override
  void onWindowClose() {
    debugPrint('🔒 [Kiosk] Permintaan menutup jendela ditolak.');
    // Tidak memanggil destroy(): itu justru menutup aplikasinya.
  }
}
