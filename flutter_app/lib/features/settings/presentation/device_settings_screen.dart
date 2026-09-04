import 'dart:io' as dart_io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/photobooth_capture_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import 'widgets/camera_settings_tab.dart';
import 'widgets/printer_settings_tab.dart';

/// Halaman Hidden Device Settings khusus Operator (Akses via Hidden Gesture Logo 5x di Welcome Screen)
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  ConsumerState<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBrown,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          onPressed: () => context.go(AppRoutes.welcome),
        ),
        title: Text(
          'HIDDEN DEVICE SETTINGS',
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.creamWhite,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.creamWhite),
            onPressed: () => context.go(AppRoutes.welcome),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.creamWhite.withValues(alpha: 0.6),
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13.sp),
          tabs: const [
            Tab(icon: Icon(Icons.print_rounded), text: 'Printer'),
            Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Camera'),
            Tab(icon: Icon(Icons.settings_suggest_rounded), text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PrinterSettingsTab(),
          CameraSettingsTab(),
          _SystemSettingsTab(),
        ],
      ),
    );
  }
}

class _SystemSettingsTab extends ConsumerWidget {
  const _SystemSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName = tenantConfig?.cafe.name ?? AppConstants.defaultCafeBrandName;
    final cafeCode = tenantConfig?.cafe.code ?? '-';
    final baseUrl = DioClient.instance.baseUrl;

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        Text(
          'INFORMASI SISTEM TENANT',
          style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Cafe: $cafeName ($cafeCode)', style: const TextStyle(color: Colors.white)),
              SizedBox(height: 6.h),
              Text('API Base URL: $baseUrl', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(height: 6.h),
              Text('Versi Aplikasi: SnapTechBooth v${AppConstants.appVersion}', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            ],
          ),
        ),

        // ── Keluar aplikasi (Windows) ───────────────────────────────────────
        //
        // Di mesin kiosk, Alt+F4 dan tombol X sengaja diblokir supaya tamu
        // tidak bisa menjatuhkan aplikasi ke desktop. Tanpa tombol ini,
        // operator pun ikut terkunci dan satu-satunya jalan keluar adalah Task
        // Manager — tidak masuk akal untuk orang yang sudah lolos PIN.
        if (!kIsWeb && dart_io.Platform.isWindows) ...[
          SizedBox(height: 24.h),
          Text(
            'KELUAR APLIKASI',
            style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
          SizedBox(height: 10.h),
          Text(
            'Alt+F4 dan tombol tutup dinonaktifkan di mesin kiosk. '
            'Gunakan tombol ini untuk menutup aplikasi.',
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmExit(context),
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Tutup Aplikasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E2A2B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Konfirmasi sebelum menutup — tombolnya berada di layar yang juga dibuka
  /// saat sesi berlangsung, dan salah tekan berarti sesi tamu ikut mati.
  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCoffee,
        title: const Text('Tutup aplikasi?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Sesi yang sedang berjalan akan berhenti, dan kamera akan dilepas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFFE57373))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Lepaskan kamera dengan rapi sebelum keluar. Helper yang mati tanpa sempat
    // melepas kamera meninggalkan handle basi, dan aplikasi berikutnya gagal
    // dengan WIA_ERROR_BUSY sampai kamera dicabut-colok.
    try {
      await PhotoboothCaptureService.instance.releasePtp();
      await PhotoboothCaptureService.instance.shutdownHelper();
    } catch (_) {}

    // destroy() melewati penjaga onWindowClose — memang itu maksudnya.
    await windowManager.destroy();
  }
}
