import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Modal Pengaturan Printer — input IP langsung, tanpa dialog system Android.
/// Android tidak mendukung listPrinters() — solusi: IPP over HTTP port 631.
class PrinterSettingsModal extends StatefulWidget {
  const PrinterSettingsModal({super.key, this.onPrinterConfigured});

  final VoidCallback? onPrinterConfigured;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onPrinterConfigured,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrinterSettingsModal(
        onPrinterConfigured: onPrinterConfigured,
      ),
    );
  }

  @override
  State<PrinterSettingsModal> createState() => _PrinterSettingsModalState();
}

class _PrinterSettingsModalState extends State<PrinterSettingsModal> {
  final _ipController = TextEditingController();
  bool _isChecking = false;
  bool _isTestingPrint = false;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  String? _savedIp;

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIp() async {
    final ip = await PrinterService.getIpAddress();
    if (mounted) {
      setState(() {
        _savedIp = ip;
        _ipController.text = ip;
      });
    }
  }

  Future<void> _checkConnection() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _statusMessage = 'Masukkan IP address printer terlebih dahulu.';
        _statusIsSuccess = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final reachable = await PrinterService.isPrinterReachable(ip: ip);

    if (mounted) {
      setState(() {
        _isChecking = false;
        _statusIsSuccess = reachable;
        _statusMessage = reachable
            ? '✅ Printer dapat dijangkau di $ip:631'
            : '❌ Printer tidak merespons di $ip:631\nPastikan printer menyala dan terhubung ke Wi-Fi yang sama.';
      });
    }
  }

  Future<void> _saveAndApply() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    await PrinterService.setIpAddress(ip);

    if (mounted) {
      setState(() {
        _savedIp = ip;
        _statusMessage = '💾 IP printer disimpan: $ip';
        _statusIsSuccess = true;
      });
      widget.onPrinterConfigured?.call();
    }
  }

  Future<void> _testPrint() async {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty && ip != _savedIp) {
      await PrinterService.setIpAddress(ip);
      setState(() => _savedIp = ip);
    }

    setState(() {
      _isTestingPrint = true;
      _statusMessage = null;
    });

    final result = await PrinterService.printTestPage();

    if (mounted) {
      setState(() {
        _isTestingPrint = false;
        _statusIsSuccess = result.isSuccess;
        _statusMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 16.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBrown,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: AppColors.gold,
                    size: 22.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENGATURAN PRINTER FOTO',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.creamWhite,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Hubungkan Epson L8050 via Wi-Fi (IP Address)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.antiqueBrass.withValues(alpha: 0.9),
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.creamWhite,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // Status printer aktif
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: (_savedIp != null ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: (_savedIp != null ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _savedIp != null
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    color:
                        _savedIp != null ? Colors.greenAccent : Colors.orange,
                    size: 18.r,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _savedIp != null
                              ? 'Printer dikonfigurasi'
                              : 'Printer belum dikonfigurasi',
                          style: GoogleFonts.montserrat(
                            color: _savedIp != null
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_savedIp != null)
                          Text(
                            'Epson L8050 — $_savedIp (IPP port 631)',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white60,
                              fontSize: 10.sp,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Input IP
            // Alamat IP hanya relevan di Android, tempat printer dijangkau
            // lewat soket. Di Windows printer datang dari spooler — USB dan
            // Wi-Fi sama saja — sehingga kolom ini menyesatkan operator.
            // Pemilihan printer di Windows ada di Hidden Settings > Printer.
            if (Platform.isWindows)
              Text(
                'Printer diambil dari daftar Windows. Ganti pilihan di '
                'Hidden Settings > Printer.',
                style: GoogleFonts.montserrat(
                  color: Colors.white54,
                  fontSize: 10.sp,
                ),
              ),
            if (Platform.isAndroid) Text(
              'IP ADDRESS PRINTER',
              style: GoogleFonts.montserrat(
                color: AppColors.gold,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            if (Platform.isAndroid) SizedBox(height: 6.h),
            if (Platform.isAndroid) Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: GoogleFonts.montserrat(
                      color: AppColors.creamWhite,
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: '192.168.1.14',
                      hintStyle: GoogleFonts.montserrat(
                        color: Colors.white30,
                        fontSize: 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.router_rounded,
                        color: AppColors.gold.withValues(alpha: 0.7),
                        size: 18.r,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: AppColors.gold,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Tombol cek koneksi
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      foregroundColor: AppColors.gold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.6),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                    ),
                    child: _isChecking
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          )
                        : Icon(Icons.network_check_rounded, size: 20.r),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              Platform.isWindows
                  ? 'Windows mengurus koneksi printer lewat driver — USB maupun Wi-Fi sama saja.'
                  : 'Cek IP di printer: Menu → Network → Wi-Fi Setup → IP Address',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white38,
                fontSize: 10.sp,
              ),
            ),

            // Status feedback
            if (_statusMessage != null) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: (_statusIsSuccess ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: (_statusIsSuccess ? Colors.green : Colors.red)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: GoogleFonts.montserrat(
                    color: _statusIsSuccess
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],

            SizedBox(height: 16.h),
            const Divider(color: Colors.white12),
            SizedBox(height: 12.h),

            // Action buttons
            Row(
              children: [
                // Simpan IP
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.darkBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: Icon(Icons.save_rounded, size: 18.r),
                    label: Text(
                      'Simpan IP',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                // Test print
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingPrint ? null : _testPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonBrown,
                      foregroundColor: AppColors.creamWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: _isTestingPrint
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.creamWhite,
                            ),
                          )
                        : Icon(Icons.print_rounded, size: 18.r),
                    label: Text(
                      _isTestingPrint ? 'Mencetak...' : 'Cetak Uji',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
