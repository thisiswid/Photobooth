import 'dart:io' as dart_io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/photobooth_capture_service.dart';
import '../../../core/services/provisioning_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import 'widgets/camera_settings_tab.dart';
import 'widgets/printer_settings_tab.dart';
import '../../../core/theme/app_fonts.dart';

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
          style: AppFonts.display(
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
          labelStyle: AppFonts.ui(fontWeight: FontWeight.w600, fontSize: 13.sp),
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
          style: AppFonts.ui(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
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

        // ── Lepas perangkat dari tenant ─────────────────────────────────────
        //
        // Aplikasi ini bukan milik satu kafe. Satu unit kiosk diikat ke sebuah
        // tenant lewat Device Key yang didaftarkan Super Admin, dan key itulah
        // yang menentukan frame, filter, harga, serta masa aktif langganan.
        //
        // Melepas perangkat menghapus key beserta konfigurasi tenant yang
        // tersimpan, lalu mengembalikan aplikasi ke layar aktivasi untuk
        // memasukkan key baru. Dipakai saat unit dipindah ke kafe lain, atau
        // saat salah memasukkan key.
        SizedBox(height: 24.h),
        Text(
          'PERANGKAT & TENANT',
          style: AppFonts.ui(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        Text(
          'Kelola Device Key yang terhubung ke tenant kafe ini. Anda dapat memasukkan key baru atau melepas perangkat.',
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showChangeKeyDialog(context, ref),
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('Ganti Key / Lepas Perangkat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
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
            style: AppFonts.ui(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
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

  /// Dialog modern untuk mengganti Device Key atau melepas perangkat
  Future<void> _showChangeKeyDialog(BuildContext context, WidgetRef ref) async {
    final cfg = ref.read(tenantNotifierProvider).valueOrNull;
    final cafeName = cfg?.cafe.name ?? 'perangkat ini';
    final currentKey = await ProvisioningService.instance.getDeviceKey() ?? '-';

    if (!context.mounted) return;

    final keyController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1611),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
              side: const BorderSide(color: Color(0xFF78350F), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 10.w),
                const Text(
                  'Pengaturan Device Key',
                  style: TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tenant Saat Ini: $cafeName',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4.h),
                          Text('Active Key: $currentKey',
                              style: TextStyle(color: const Color(0xFFFDE68A), fontSize: 12.sp, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'MASUKKAN KEY BARU',
                      style: TextStyle(color: const Color(0xFFD97706), fontSize: 11.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.h),
                    TextField(
                      controller: keyController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      decoration: InputDecoration(
                        hintText: 'CONTOH: SNAP-FK-9921',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF140E0A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFF78350F)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      ),
                    ),
                    if (errorText != null) ...[
                      SizedBox(height: 8.h),
                      Text(errorText!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
                    ],
                    SizedBox(height: 14.h),
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Belum punya key baru? Hubungi Admin SnapTech untuk menerbitkan pairing key.',
                              style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal', style: TextStyle(color: Colors.white60)),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final confirmUnpair = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            backgroundColor: AppColors.darkCoffee,
                            title: const Text('Lepas Perangkat?', style: TextStyle(color: Colors.white)),
                            content: Text(
                              'Perangkat akan dilepas dari "$cafeName" dan kembali ke layar aktivasi awal.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Lepas', style: TextStyle(color: Color(0xFFE57373))),
                              ),
                            ],
                          ),
                        );
                        if (confirmUnpair == true) {
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          try {
                            await PhotoboothCaptureService.instance.releasePtp();
                          } catch (_) {}
                          await ref.read(tenantNotifierProvider.notifier).unpairDevice();
                          if (context.mounted) {
                            context.go(AppRoutes.provisioning);
                          }
                        }
                      },
                child: const Text('Lepas Perangkat', style: TextStyle(color: Color(0xFFE57373))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final newKey = keyController.text.trim().toUpperCase();
                        if (newKey.isEmpty) {
                          setModalState(() => errorText = 'Silakan masukkan Device Key baru.');
                          return;
                        }

                        setModalState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        try {
                          await ref.read(tenantNotifierProvider.notifier).activateDevice(deviceKey: newKey);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Device Key berhasil diperbarui!'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                            context.go(AppRoutes.welcome);
                          }
                        } catch (e) {
                          setModalState(() {
                            isLoading = false;
                            errorText = e.toString().replaceAll('Exception:', '').trim();
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan & Pasang Key'),
              ),
            ],
          );
        },
      ),
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
