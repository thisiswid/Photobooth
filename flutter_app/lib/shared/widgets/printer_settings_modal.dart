import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Modal Pengaturan Printer Khusus di Halaman Hasil (Final Result Screen) — Tanpa Password
class PrinterSettingsModal extends StatefulWidget {
  const PrinterSettingsModal({super.key, this.onPrinterSelected});

  final ValueChanged<Printer>? onPrinterSelected;

  static Future<void> show(BuildContext context, {ValueChanged<Printer>? onPrinterSelected}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrinterSettingsModal(onPrinterSelected: onPrinterSelected),
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
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoading = true);
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
      _testMessage = null;
    });

    final result = await PrinterService.printTestPage();

    if (mounted) {
      setState(() {
        _isTestingPrint = false;
        _testMessage = result.message;
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
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
      constraints: BoxConstraints(maxHeight: 520.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Title & Close
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.print_rounded, color: AppColors.gold, size: 22.r),
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
                      'Pilih printer Epson L8050 / USB / Wi-Fi yang terhubung',
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
          const Divider(color: Colors.white12, height: 24),

          // Active Selected Printer Banner
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: (_selectedPrinter != null ? Colors.green : Colors.orange).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: (_selectedPrinter != null ? Colors.green : Colors.orange).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPrinter != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: _selectedPrinter != null ? Colors.greenAccent : Colors.orangeAccent,
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
                            : 'Belum ada printer yang dipilih',
                        style: GoogleFonts.montserrat(
                          color: _selectedPrinter != null ? Colors.greenAccent : Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5.sp,
                        ),
                      ),
                      Text(
                        _selectedPrinter != null
                            ? 'Print job akan langsung dikirim ke printer ini tanpa dialog.'
                            : 'Silakan pilih dari daftar printer di bawah.',
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
          SizedBox(height: 12.h),

          // List of detected printers
          Text(
            'PRINTER TERDETEKSI:',
            style: GoogleFonts.montserrat(
              color: AppColors.gold,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 6.h),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else if (_printers.isEmpty)
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.print_disabled_rounded, color: Colors.redAccent, size: 24.r),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Tidak ada printer yang terdeteksi. Pastikan kabel USB / Wi-Fi Epson L8050 tersambung.',
                      style: TextStyle(color: AppColors.creamWhite.withValues(alpha: 0.8), fontSize: 11.5.sp),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _printers.length,
                itemBuilder: (context, idx) {
                  final p = _printers[idx];
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
                        'URL / Port: ${p.url.isNotEmpty ? p.url : 'USB / Local Print Service'}',
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
                                widget.onPrinterSelected?.call(p);
                              },
                              child: Text('Pilih', style: TextStyle(color: AppColors.antiqueBrass)),
                            ),
                      onTap: () {
                        setState(() => _selectedPrinter = p);
                        PrinterService.setSelectedPrinter(p);
                        widget.onPrinterSelected?.call(p);
                      },
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: 12.h),

          // Actions: Test Print & Rescan
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isTestingPrint ? null : _testPrint,
                  icon: _isTestingPrint
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBrown),
                        )
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    _isTestingPrint ? 'Mencetak...' : 'Cetak Halaman Uji',
                    style: GoogleFonts.montserrat(fontSize: 12.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),

          if (_testMessage != null) ...[
            SizedBox(height: 8.h),
            Center(
              child: Text(
                _testMessage!,
                style: TextStyle(color: Colors.amberAccent, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
