import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Modal Pengaturan Printer Khusus di Halaman Hasil (Final Result Screen) — Tanpa Password
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
  List<Printer> _printers = [];
  Printer? _selectedPrinter;
  bool _isLoading = true;
  bool _isTestingPrint = false;
  String? _statusMessage;
  bool _statusIsSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final printers = await PrinterService.getAvailablePrinters();
    final epson = await PrinterService.findEpsonPrinter(maxRetries: 1);

    if (mounted) {
      setState(() {
        _printers = printers;
        _selectedPrinter = PrinterService.selectedPrinter ?? epson;
        _isLoading = false;
      });
    }
  }

  Future<void> _testPrint() async {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      constraints: BoxConstraints(maxHeight: 540.h),
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
                        'Pilih printer Epson L8050 yang terhubung via USB / Wi-Fi',
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

            // Active Selected Printer Banner
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: (_selectedPrinter != null ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: (_selectedPrinter != null ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedPrinter != null
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _selectedPrinter != null ? Colors.greenAccent : Colors.orange,
                    size: 22.r,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPrinter != null
                              ? 'Printer Aktif: ${_selectedPrinter!.name}'
                              : 'Mencari printer otomatis...',
                          style: GoogleFonts.montserrat(
                            color: _selectedPrinter != null
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _selectedPrinter != null
                              ? 'Format foto 4R (4×6 inch) siap dicetak 1 lembar.'
                              : 'Pastikan Epson L8050 menyala dan terhubung.',
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

            // List of detected printers
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

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (_printers.isEmpty)
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.print_disabled_rounded, color: Colors.orangeAccent, size: 22.r),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Epson L8050 akan dipilih otomatis melalui Print Service saat tombol Cetak ditekan.',
                        style: TextStyle(color: AppColors.creamWhite.withValues(alpha: 0.8), fontSize: 11.5.sp),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._printers.map((p) {
                final isSelected = _selectedPrinter?.url == p.url || _selectedPrinter?.name == p.name;
                return Card(
                  color: isSelected ? AppColors.gold.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.3),
                  margin: EdgeInsets.only(bottom: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(
                      color: isSelected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.print_rounded,
                      color: isSelected ? AppColors.gold : AppColors.creamWhite,
                    ),
                    title: Text(
                      p.name,
                      style: GoogleFonts.montserrat(
                        color: AppColors.creamWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    subtitle: Text(
                      'Interface: ${p.url.isNotEmpty ? p.url : 'USB / Local Network'}',
                      style: TextStyle(color: AppColors.creamWhite.withValues(alpha: 0.65), fontSize: 11.sp),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'TERPILIH',
                              style: GoogleFonts.montserrat(
                                color: AppColors.darkBrown,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.sp,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: () {
                              setState(() => _selectedPrinter = p);
                              PrinterService.setSelectedPrinter(p);
                              widget.onPrinterConfigured?.call();
                            },
                            child: Text('Pilih', style: TextStyle(color: AppColors.antiqueBrass)),
                          ),
                    onTap: () {
                      setState(() => _selectedPrinter = p);
                      PrinterService.setSelectedPrinter(p);
                      widget.onPrinterConfigured?.call();
                    },
                  ),
                );
              }),

            SizedBox(height: 12.h),

            // Status feedback
            if (_statusMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: (_statusIsSuccess ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: (_statusIsSuccess ? Colors.green : Colors.red).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: GoogleFonts.montserrat(
                    color: _statusIsSuccess ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: AppColors.gold,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: _isLoading ? null : _loadPrinters,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Pindai Ulang', style: GoogleFonts.montserrat(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingPrint ? null : _testPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.darkBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    icon: _isTestingPrint
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.darkBrown,
                            ),
                          )
                        : Icon(Icons.print_rounded, size: 18.r),
                    label: Text(
                      _isTestingPrint ? 'Mencetak...' : 'Cetak 1 Lembar Uji',
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
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
