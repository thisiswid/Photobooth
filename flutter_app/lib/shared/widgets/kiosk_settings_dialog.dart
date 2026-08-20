import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Modal Dialog Pengaturan Hardware Kiosk (Kamera, Printer, & Status Sistem)
class KioskSettingsDialog extends StatefulWidget {
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
  State<KioskSettingsDialog> createState() => _KioskSettingsDialogState();
}

class _KioskSettingsDialogState extends State<KioskSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CameraDescription> _cameras = [];
  CameraDescription? _activeCamera;
  bool _isLoadingCameras = true;

  List<Printer> _printers = [];
  Printer? _activePrinter;
  bool _isLoadingPrinters = true;
  bool _isTestingPrint = false;
  String? _printTestMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHardware();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHardware() async {
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
    final printers = await PrinterService.getAvailablePrinters();
    final epson = await PrinterService.findEpsonPrinter(maxRetries: 1);
    if (mounted) {
      setState(() {
        _printers = printers;
        _activePrinter = PrinterService.selectedPrinter ?? epson;
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Container(
        width: 640.w,
        constraints: BoxConstraints(maxHeight: 560.h),
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
                          'PENGATURAN HARDWARE KIOSK',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppColors.creamWhite,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Diagnostik Kamera & Printer Photobooth',
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

            // ── Tab Bar ───────────────────────────────────────────────────
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
                      'Pindai Ulang Perangkat',
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

  Widget _buildCameraTab() {
    if (_isLoadingCameras) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (_cameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48.r),
            SizedBox(height: 12.h),
            Text(
              'Tidak Ada Kamera Terdeteksi',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.creamWhite),
            ),
            SizedBox(height: 6.h),
            Text(
              'Pastikan Capture Card / USB Camera terhubung ke kiosk.',
              style: AppTextStyles.caption.copyWith(color: AppColors.creamWhite.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // Status Card
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: Kamera Terhubung & Siap Digunakan',
                      style: GoogleFonts.montserrat(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    Text(
                      'Total ${_cameras.length} perangkat kamera terpasang di sistem.',
                      style: TextStyle(
                        color: AppColors.creamWhite.withValues(alpha: 0.8),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        Text(
          'PILIH KAMERA AKTIF:',
          style: GoogleFonts.montserrat(
            color: AppColors.gold,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 8.h),

        ..._cameras.map((cam) {
          final isSelected = _activeCamera?.name == cam.name;
          final isExt = CameraService.isExternalCamera(cam);
          final label = CameraService.getCameraTypeLabel(cam);

          return Card(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
              side: BorderSide(
                color: isSelected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            margin: EdgeInsets.only(bottom: 8.h),
            child: ListTile(
              leading: Icon(
                isExt ? Icons.camera_enhance_rounded : Icons.photo_camera_front_rounded,
                color: isSelected ? AppColors.gold : AppColors.creamWhite,
                size: 28.r,
              ),
              title: Text(
                cam.name.isNotEmpty ? cam.name : 'Camera (${cam.lensDirection.name})',
                style: GoogleFonts.montserrat(
                  color: AppColors.creamWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                ),
              ),
              subtitle: Text(
                label,
                style: TextStyle(
                  color: isExt ? Colors.amberAccent : AppColors.creamWhite.withValues(alpha: 0.7),
                  fontSize: 11.5.sp,
                ),
              ),
              trailing: isSelected
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'AKTIF',
                        style: GoogleFonts.montserrat(
                          color: AppColors.darkBrown,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.sp,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () {
                        setState(() {
                          _activeCamera = cam;
                          CameraService.setSelectedCamera(cam);
                        });
                        widget.onCameraChanged?.call();
                      },
                      child: Text('Gunakan', style: TextStyle(color: AppColors.antiqueBrass)),
                    ),
              onTap: () {
                setState(() {
                  _activeCamera = cam;
                  CameraService.setSelectedCamera(cam);
                });
                widget.onCameraChanged?.call();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrinterTab() {
    if (_isLoadingPrinters) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    final hasPrinter = _printers.isNotEmpty || _activePrinter != null;

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // Printer Status Card
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: (hasPrinter ? Colors.green : Colors.orange).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: (hasPrinter ? Colors.green : Colors.orange).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasPrinter ? Icons.print_rounded : Icons.print_disabled_rounded,
                color: hasPrinter ? Colors.greenAccent : Colors.orangeAccent,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPrinter ? 'Printer Terhubung (Epson L8050 / Print Service)' : 'Mencari Printer...',
                      style: GoogleFonts.montserrat(
                        color: hasPrinter ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    Text(
                      _activePrinter != null
                          ? 'Aktif: ${_activePrinter!.name}'
                          : 'Printer foto siap mencetak format 4R.',
                      style: TextStyle(
                        color: AppColors.creamWhite.withValues(alpha: 0.8),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // Test Print Section
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
                'UJI COBA PENCETAKAN (TEST PRINT)',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Cetak 1 lembar halaman diagnostik untuk memverifikasi kesiapan kertas & tinta.',
                style: TextStyle(
                  color: AppColors.creamWhite.withValues(alpha: 0.75),
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
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
                ],
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

        if (_printers.isNotEmpty) ...[
          SizedBox(height: 14.h),
          Text(
            'DAFTAR PRINTER TERDETEKSI:',
            style: GoogleFonts.montserrat(
              color: AppColors.gold,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          ..._printers.map((printer) {
            final isSelected = _activePrinter?.url == printer.url || _activePrinter?.name == printer.name;
            return Card(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
                side: BorderSide(
                  color: isSelected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              margin: EdgeInsets.only(bottom: 8.h),
              child: ListTile(
                leading: Icon(
                  Icons.print_rounded,
                  color: isSelected ? AppColors.gold : AppColors.creamWhite,
                  size: 24.r,
                ),
                title: Text(
                  printer.name,
                  style: GoogleFonts.montserrat(
                    color: AppColors.creamWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5.sp,
                  ),
                ),
                subtitle: Text(
                  'URL: ${printer.url.isNotEmpty ? printer.url : 'Default Local USB/WiFi'}',
                  style: TextStyle(
                    color: AppColors.creamWhite.withValues(alpha: 0.65),
                    fontSize: 11.sp,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20.r)
                    : TextButton(
                        onPressed: () {
                          setState(() {
                            _activePrinter = printer;
                            PrinterService.setSelectedPrinter(printer);
                          });
                        },
                        child: Text('Pilih', style: TextStyle(color: AppColors.antiqueBrass)),
                      ),
                onTap: () {
                  setState(() {
                    _activePrinter = printer;
                    PrinterService.setSelectedPrinter(printer);
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }
}
