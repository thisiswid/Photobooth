import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/router/app_router.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/provisioning_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/provisioning/providers/tenant_provider.dart';

/// Modal Dialog Pengaturan Hardware Kiosk (Tenant, Kamera, Printer, & Diagnostik Sistem)
class KioskSettingsDialog extends ConsumerStatefulWidget {
  const KioskSettingsDialog({
    super.key,
    this.onCameraChanged,
  });

  final VoidCallback? onCameraChanged;

  static Future<void> show(BuildContext context, {VoidCallback? onCameraChanged}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => KioskSettingsDialog(onCameraChanged: onCameraChanged),
    );
  }

  @override
  ConsumerState<KioskSettingsDialog> createState() => _KioskSettingsDialogState();
}

class _KioskSettingsDialogState extends ConsumerState<KioskSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CameraDescription> _cameras = [];
  CameraDescription? _activeCamera;
  bool _isLoadingCameras = true;

  String? _printerIp;
  bool _isLoadingPrinters = true;
  bool _isPrinterReachable = false;
  final _ipController = TextEditingController();
  bool _isTestingPrint = false;
  String? _printTestMessage;

  bool _isSyncing = false;
  String? _deviceKeyStored;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHardware();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadHardware() async {
    final devKey = await ProvisioningService.instance.getDeviceKey();
    if (mounted) {
      setState(() {
        _deviceKeyStored = devKey;
      });
    }

    await Future.wait([
      _loadCameras(),
      _loadPrinters(),
    ]);
  }

  Future<void> _loadCameras() async {
    setState(() => _isLoadingCameras = true);
    final cameras = await CameraService.getAvailableCamerasList();
    final active = await CameraService.getBestCamera();
    if (mounted) {
      setState(() {
        _cameras = cameras;
        _activeCamera = active;
        _isLoadingCameras = false;
      });
    }
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final ip = await PrinterService.getIpAddress();
    final reachable = await PrinterService.isPrinterReachable(ip: ip);
    if (mounted) {
      setState(() {
        _printerIp = ip;
        _ipController.text = ip;
        _isPrinterReachable = reachable;
        _isLoadingPrinters = false;
      });
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _isTestingPrint = true;
      _printTestMessage = null;
    });

    final result = await PrinterService.printTestPage();

    if (mounted) {
      setState(() {
        _isTestingPrint = false;
        _printTestMessage = result.message;
      });
    }
  }

  Future<void> _handleForceSync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(tenantNotifierProvider.notifier).refreshConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('Konfigurasi dan aset tenant berhasil disinkronkan!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Gagal sinkronisasi: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleUnpairDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1611),
        title: Text(
          'Lepas / Unpair Mesin Ini?',
          style: GoogleFonts.cormorantGaramond(
            color: const Color(0xFFF87171),
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin melepas pairing mesin kiosk ini? Konfigurasi lokal akan di-reset dan aplikasi akan kembali ke Layar Aktivasi.',
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Unpair Mesin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(tenantNotifierProvider.notifier).unpairDevice();
      if (!mounted) return;
      Navigator.of(context).pop(); // Tutup modal settings
      context.go(AppRoutes.provisioning); // Arahkan ke Layar Aktivasi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Container(
        width: 680.w,
        constraints: BoxConstraints(maxHeight: 580.h),
        decoration: BoxDecoration(
          color: AppColors.darkBrown,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.gold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog Header ──────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                border: Border(
                  bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Icon(Icons.settings_rounded, color: AppColors.gold, size: 22.r),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PENGATURAN KIOSK SNAPTECH',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppColors.creamWhite,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Manajemen Tenant, Kamera, & Printer Photobooth',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.antiqueBrass.withValues(alpha: 0.9),
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.creamWhite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Tab Bar (3 Tabs) ─────────────────────────────────────────
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.gold,
                indicatorWeight: 3,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.creamWhite.withValues(alpha: 0.6),
                labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13.sp),
                tabs: const [
                  Tab(icon: Icon(Icons.store_rounded), text: 'Tenant & Mesin'),
                  Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Kamera'),
                  Tab(icon: Icon(Icons.print_outlined), text: 'Printer'),
                ],
              ),
            ),

            // ── Tab Content ───────────────────────────────────────────────
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTenantTab(),
                  _buildCameraTab(),
                  _buildPrinterTab(),
                ],
              ),
            ),

            // ── Dialog Footer ──────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15.r)),
                border: Border(
                  top: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _loadHardware,
                    icon: Icon(Icons.refresh_rounded, color: AppColors.gold, size: 18.r),
                    label: Text(
                      'Pindai Ulang Status',
                      style: TextStyle(color: AppColors.gold, fontSize: 12.sp),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.darkBrown,
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Selesai',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 1: Tenant & Manajemen Mesin ───────────────────────────────────────

  Widget _buildTenantTab() {
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName = tenantConfig?.cafe.name ?? AppConstants.defaultCafeBrandName;
    final cafeCode = tenantConfig?.cafe.code ?? '-';
    final eventName = tenantConfig?.event?.name ?? 'Event Utama';
    final deviceKey = _deviceKeyStored ?? tenantConfig?.device?.deviceKey ?? '-';
    final baseUrl = DioClient.instance.baseUrl;

    return ListView(
      padding: EdgeInsets.all(18.r),
      children: [
        // Kartu Identitas Cafe & Device
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INFORMASI TENANT & LISENSI',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12.h),
              _buildInfoRow('Nama Tenant / Cafe:', cafeName),
              _buildInfoRow('Kode Tenant:', cafeCode),
              _buildInfoRow('Event Aktif:', eventName),
              _buildInfoRow('Device Pairing Key:', deviceKey),
              _buildInfoRow('API Base URL:', baseUrl),
              _buildInfoRow('Versi Aplikasi:', 'SnapTechBooth v${AppConstants.appVersion}'),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Aksi Manajemen Mesin
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.darkBrown,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: _isSyncing ? null : _handleForceSync,
                icon: _isSyncing
                    ? SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBrown),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Ulang Config',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12.sp),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  side: const BorderSide(color: Color(0xFFF87171)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                onPressed: _handleUnpairDevice,
                icon: const Icon(Icons.link_off_rounded),
                label: Text(
                  'Unpair / Reset Mesin',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12.sp),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150.w,
            child: Text(
              label,
              style: TextStyle(color: Colors.white60, fontSize: 12.sp),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Kamera ─────────────────────────────────────────────────────────

  Widget _buildCameraTab() {
    if (_isLoadingCameras) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KAMERA AKTIF',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 8.h),
              if (_activeCamera != null)
                Row(
                  children: [
                    Icon(
                      _activeCamera!.lensDirection == CameraLensDirection.external
                          ? Icons.videocam_rounded
                          : Icons.photo_camera_rounded,
                      color: AppColors.gold,
                      size: 20.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _activeCamera!.name,
                        style: GoogleFonts.montserrat(
                          color: AppColors.creamWhite,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: const Color(0xFF22C55E)),
                      ),
                      child: Text(
                        'AKTIF',
                        style: TextStyle(
                          color: const Color(0xFF22C55E),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Tidak ada kamera yang terdeteksi',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          'DAFTAR KAMERA TERDETEKSI (${_cameras.length})',
          style: GoogleFonts.montserrat(
            color: AppColors.gold,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 8.h),
        ..._cameras.map((cam) {
          final isSelected = cam.name == _activeCamera?.name;
          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold
                    : AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                cam.lensDirection == CameraLensDirection.external
                    ? Icons.videocam_rounded
                    : Icons.photo_camera_rounded,
                color: isSelected ? AppColors.gold : AppColors.creamWhite.withValues(alpha: 0.7),
              ),
              title: Text(
                cam.name,
                style: GoogleFonts.montserrat(
                  color: AppColors.creamWhite,
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Arah: ${cam.lensDirection.name}',
                style: TextStyle(color: Colors.white60, fontSize: 10.5.sp),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.gold)
                  : TextButton(
                      child: Text('Pilih', style: TextStyle(color: AppColors.gold, fontSize: 11.sp)),
                      onPressed: () {
                        setState(() => _activeCamera = cam);
                        widget.onCameraChanged?.call();
                      },
                    ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Tab 3: Printer ────────────────────────────────────────────────────────

  Widget _buildPrinterTab() {
    if (_isLoadingPrinters) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // Status Printer Card
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: _isPrinterReachable
                  ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                  : Colors.redAccent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS EPSON L8050',
                    style: GoogleFonts.montserrat(
                      color: AppColors.gold,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: _isPrinterReachable
                          ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                          : Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: _isPrinterReachable
                            ? const Color(0xFF22C55E)
                            : Colors.redAccent,
                      ),
                    ),
                    child: Text(
                      _isPrinterReachable ? 'TERHUBUNG (SIAP)' : 'TIDAK TERJANGKAU',
                      style: TextStyle(
                        color: _isPrinterReachable
                            ? const Color(0xFF22C55E)
                            : Colors.redAccent,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Target: Epson L8050 Photo Printer via Android Print Service',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.creamWhite.withValues(alpha: 0.8),
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(height: 12.h),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.darkBrown,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                onPressed: _isTestingPrint ? null : _testPrint,
                icon: _isTestingPrint
                    ? SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBrown),
                      )
                    : const Icon(Icons.print_rounded),
                label: Text(
                  _isTestingPrint ? 'Mengirim ke printer...' : 'Cetak Halaman Uji',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12.sp),
                ),
              ),
              if (_printTestMessage != null) ...[
                SizedBox(height: 8.h),
                Text(
                  _printTestMessage!,
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 14.h),

        // IP Address Input Section
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IP ADDRESS PRINTER',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Cek IP: Menu → Network → Wi-Fi Setup → IP Address',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.creamWhite.withValues(alpha: 0.6),
                  fontSize: 10.sp,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: GoogleFonts.montserrat(
                        color: AppColors.creamWhite,
                        fontSize: 13.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: '192.168.1.14',
                        hintStyle: GoogleFonts.montserrat(color: Colors.white30, fontSize: 13.sp),
                        prefixIcon: Icon(Icons.router_rounded, color: AppColors.gold.withValues(alpha: 0.7), size: 18.r),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.darkBrown,
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: () async {
                      final ip = _ipController.text.trim();
                      if (ip.isEmpty) return;
                      await PrinterService.setIpAddress(ip);
                      final reachable = await PrinterService.isPrinterReachable(ip: ip);
                      if (mounted) {
                        setState(() {
                          _printerIp = ip;
                          _isPrinterReachable = reachable;
                        });
                      }
                    },
                    child: Text(
                      'Simpan',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
