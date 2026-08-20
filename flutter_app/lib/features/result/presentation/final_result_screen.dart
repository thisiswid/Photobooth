import 'dart:async';
import 'dart:io' as dart_io;
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/printer_settings_modal.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

enum PrintUiStatus {
  idle,
  preparing,
  printing,
  success,
  failed,
}

/// Final Result Screen — header transparan centered 2x.
/// "Hasil Foto" di bawah header.
/// Preview foto LEBIH LEBAR dari QR.
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  PrintUiStatus _printStatus = PrintUiStatus.idle;
  String _printStatusMessage = '';
  String? _connectedPrinterName;
  int _printRetryCount = 0;
  bool _hasAutoPrinted = false;

  @override
  void initState() {
    super.initState();
    _triggerBackendGenerationAndAutoPrint();
  }

  /// URL helper for backend storage
  String _getStorageUrl(String relativePath) {
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    String clean = relativePath;
    if (clean.startsWith('/')) clean = clean.substring(1);
    if (clean.startsWith('storage/')) clean = clean.substring('storage/'.length);
    final storageBase = AppConstants.apiBaseUrlDev.replaceAll('/api', '/storage');
    return '$storageBase/$clean';
  }

  Future<void> _triggerBackendGenerationAndAutoPrint() async {
    final sessionState = ref.read(sessionNotifierProvider);
    final session = sessionState.session;
    if (session == null) return;

    setState(() {
      _printStatus = PrintUiStatus.preparing;
      _printStatusMessage = 'Menyiapkan hasil foto HD...';
    });

    String? generatedFinalUrl;

    try {
      final dio_pkg.FormData formData = dio_pkg.FormData();

      if (session.filterId != null) {
        formData.fields.add(MapEntry('filter_id', session.filterId.toString()));
      }
      if (session.selectedFilter != null) {
        formData.fields.add(MapEntry('selected_filter', session.selectedFilter!));
      }
      if (session.frameId != null) {
        formData.fields.add(MapEntry('frame_id', session.frameId.toString()));
      }
      formData.fields.add(MapEntry('event_id', session.eventId.toString()));

      for (int i = 0; i < session.photos.length; i++) {
        final path = session.photos[i].fileUrl;
        final file = dart_io.File(path);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'photos[]',
            await dio_pkg.MultipartFile.fromFile(
              path,
              filename: 'pose_${i + 1}.jpg',
            ),
          ));
        } else {
          formData.fields.add(MapEntry('photos[]', path));
        }
      }

      final response = await DioClient.instance.dio.post(
        '/sessions/${session.sessionId}/generate-result',
        data: formData,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final data = response.data['data'];
        generatedFinalUrl = data['final_url'] ?? '';
        ref.read(sessionNotifierProvider.notifier).setResult(
          finalUrl: generatedFinalUrl ?? '',
          gifUrl:   data['gif_url'] ?? '',
          qrToken:  data['qr_token'] ?? '',
        );
      }
    } catch (e) {
      debugPrint('Backend result generation note: $e');
    }

    // Auto-Print langsung setelah foto & template siap
    if (!_hasAutoPrinted && mounted) {
      _hasAutoPrinted = true;
      await _executePrint(finalUrl: generatedFinalUrl);
    }
  }

  /// Eksekusi pengiriman print ke Epson L8050
  Future<void> _executePrint({String? finalUrl}) async {
    if (!mounted) return;

    setState(() {
      _printStatus = PrintUiStatus.printing;
      _printStatusMessage = 'Mengirim data ke printer Epson L8050...';
    });

    try {
      Uint8List? imageBytes;

      // 1. Coba ambil dari final_url backend (hasil render lengkap frame + filter)
      if (finalUrl != null && finalUrl.isNotEmpty) {
        try {
          final fullUrl = _getStorageUrl(finalUrl);
          debugPrint('📥 Mengunduh hasil render HD untuk dicetak: $fullUrl');
          final response = await DioClient.instance.dio.get<List<int>>(
            fullUrl,
            options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
          );
          if (response.data != null) {
            imageBytes = Uint8List.fromList(response.data!);
          }
        } catch (e) {
          debugPrint('Download final photo bytes failed, falling back to local files: $e');
        }
      }

      // 2. Fallback ke file foto lokal jika unduhan backend belum ada
      if (imageBytes == null) {
        final sessionState = ref.read(sessionNotifierProvider);
        final session = sessionState.session;
        if (session != null && session.photos.isNotEmpty) {
          final firstPhotoPath = session.photos.first.fileUrl;
          final file = dart_io.File(firstPhotoPath);
          if (await file.exists()) {
            imageBytes = await file.readAsBytes();
          }
        }
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        setState(() {
          _printStatus = PrintUiStatus.failed;
          _printStatusMessage = 'File foto tidak ditemukan untuk dicetak.';
        });
        return;
      }

      // 3. Kirim ke PrinterService
      final result = await PrinterService.printPhotoBytes(imageBytes: imageBytes);

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _printStatus = PrintUiStatus.success;
          _connectedPrinterName = result.printerName ?? 'Epson L8050';
          _printStatusMessage = result.message;
        });
      } else {
        setState(() {
          _printStatus = PrintUiStatus.failed;
          _printStatusMessage = result.message;
        });
      }
    } catch (e, stack) {
      debugPrint('Print error: $e');
      ErrorLogger.instance.logHardwareError(
        message: 'Gagal menjalankan proses cetak otomatis: $e',
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _printStatus = PrintUiStatus.failed;
          _printStatusMessage = 'Gagal mencetak: $e';
        });
      }
    }
  }

  Future<void> _handleManualPrintRetry() async {
    if (_printStatus == PrintUiStatus.printing || _printStatus == PrintUiStatus.preparing) return;

    _printRetryCount++;
    ErrorLogger.instance.logRetryAttempt(
      action: 'Print Photo',
      attempt: _printRetryCount,
      reason: _printStatusMessage,
    );

    final sessionState = ref.read(sessionNotifierProvider);
    await _executePrint(finalUrl: sessionState.session?.finalUrl);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _finishSession() {
    ref.read(sessionNotifierProvider.notifier).resetSession();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final session = sessionState.session;
    final photos = session?.photos ?? [];
    final frame = sessionState.selectedFrame;

    final qrToken = session?.qrToken;
    final hasQrToken = qrToken != null && qrToken.trim().isNotEmpty;
    final qrUrl = hasQrToken
        ? '${AppConstants.resultBaseUrl}/$qrToken'
        : null;

    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    final actionPanel = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QrCard(qrUrl: qrUrl),
        SizedBox(height: isMobile ? 8.h : 12.h),

        // ── UI Status Cetak (Loading / Berhasil / Gagal) ──
        _buildPrintStatusWidget(),
        SizedBox(height: isMobile ? 6.h : 8.h),

        // ── Tombol Cetak / Cetak Ulang ───────────────────
        SizedBox(
          width: double.infinity,
          height: isMobile ? 42.h : 46.h,
          child: OutlinedButton(
            onPressed: (_printStatus == PrintUiStatus.printing || _printStatus == PrintUiStatus.preparing)
                ? null
                : _handleManualPrintRetry,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.creamWhite,
              foregroundColor: AppColors.darkBrown,
              side: const BorderSide(color: AppColors.darkBrown, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              (_printStatus == PrintUiStatus.printing || _printStatus == PrintUiStatus.preparing)
                  ? 'Sedang mencetak...'
                  : 'Cetak',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 12.5.sp : 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.darkBrown,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),

        SizedBox(height: isMobile ? 8.h : 10.h),

        // ── Tombol Selesai (Tanpa Tulisan di Bawahnya) ──
        SizedBox(
          width: double.infinity,
          height: isMobile ? 42.h : 46.h,
          child: ElevatedButton(
            onPressed: _finishSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonBrown,
              foregroundColor: AppColors.creamWhite,
              elevation: 3,
              shadowColor: AppColors.darkBrown.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
                side: const BorderSide(color: AppColors.gold, width: 1.0),
              ),
            ),
            child: Text(
              'Selesai',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 13.sp : 14.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.creamWhite,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 300.ms),

        SizedBox(height: 6.h),

        // ── Link Pengaturan Printer Cepat (Tanpa Password) ──
        TextButton.icon(
          onPressed: () => PrinterSettingsModal.show(
            context,
            onPrinterSelected: (p) => setState(() => _connectedPrinterName = p.name),
          ),
          icon: Icon(Icons.tune_rounded, size: 15.r, color: AppColors.brown),
          label: Text(
            _connectedPrinterName != null
                ? 'Printer: $_connectedPrinterName'
                : 'Pengaturan Printer',
            style: TextStyle(
              color: AppColors.brown,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ).animate().slideX(begin: 0.05, delay: 200.ms);

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Hasil Foto" & Tombol Setting Printer di bawah header
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 14.w : 32.w, 4.h, isMobile ? 14.w : 32.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hasil Foto',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: isMobile ? 22.sp : 30.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBrown,
                  ),
                ).animate().fadeIn(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    side: const BorderSide(color: AppColors.gold, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    backgroundColor: AppColors.creamWhite.withValues(alpha: 0.6),
                  ),
                  onPressed: () => PrinterSettingsModal.show(
                    context,
                    onPrinterSelected: (p) => setState(() => _connectedPrinterName = p.name),
                  ),
                  icon: Icon(Icons.print_rounded, size: 16.r, color: AppColors.darkBrown),
                  label: Text(
                    _connectedPrinterName != null ? _connectedPrinterName! : 'Set Printer',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkBrown,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 6.h : 10.h),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.w : 32.w),
              child: isMobile || isPortrait
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          Center(
                            child: SizedBox(
                              height: 380.h,
                              child: PhotoStripWidget(
                                photos: photos,
                                frame: frame,
                                colorFilter: sessionState.selectedFilter?.colorFilter,
                              ),
                            ),
                          ),
                          SizedBox(height: 14.h),
                          actionPanel,
                          SizedBox(height: 16.h),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        // ── Preview Photo Strip dengan Frame (flex: 3) ─────────
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: PhotoStripWidget(
                              photos: photos,
                              frame: frame,
                              colorFilter: sessionState.selectedFilter?.colorFilter,
                            ),
                          ).animate().scale(begin: const Offset(0.95, 0.95), duration: 500.ms).fadeIn(duration: 500.ms),
                        ),

                        SizedBox(width: 24.w),

                        // ── QR + Status Print + Selesai (flex: 2) ─────────────
                        Expanded(
                          flex: 2,
                          child: actionPanel,
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: isMobile ? 6.h : 12.h),
        ],
      ),
    );
  }

  /// Widget Indikator Status Cetak Real-Time
  Widget _buildPrintStatusWidget() {
    switch (_printStatus) {
      case PrintUiStatus.preparing:
      case PrintUiStatus.printing:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 1.2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18.r,
                height: 18.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBrown),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  _printStatusMessage.isNotEmpty ? _printStatusMessage : 'Sedang memproses & mencetak foto...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.darkBrown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn();

      case PrintUiStatus.success:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF2E7D32), size: 20.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Foto berhasil dikirim ke printer! Silakan ambil di ${_connectedPrinterName ?? "printer"}.',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn();

      case PrintUiStatus.failed:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFEF5350), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: const Color(0xFFC62828), size: 20.r),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _printStatusMessage.isNotEmpty
                          ? _printStatusMessage
                          : 'Gagal terhubung ke printer Epson L8050.',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFFB71C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => PrinterSettingsModal.show(
                      context,
                      onPrinterSelected: (p) => setState(() => _connectedPrinterName = p.name),
                    ),
                    icon: Icon(Icons.settings_rounded, size: 14.r, color: const Color(0xFFB71C1C)),
                    label: Text(
                      'Pilih Printer / Cek Koneksi',
                      style: TextStyle(
                        color: const Color(0xFFB71C1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn();

      case PrintUiStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({this.qrUrl});
  final String? qrUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.darkBrown, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Download Foto',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBrown,
            ),
          ).animate().fadeIn(delay: 200.ms),
          SizedBox(height: 8.h),
          Container(
            width: 140.r,
            height: 140.r,
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: qrUrl != null && qrUrl!.isNotEmpty
                ? QrImageView(
                    data: qrUrl!,
                    version: QrVersions.auto,
                    size: 124.r,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  )
                : const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.darkBrown,
                      ),
                    ),
                  ),
          ).animate().scale(
                begin: const Offset(0.9, 0.9),
                duration: 400.ms,
                delay: 200.ms,
              ),
        ],
      ),
    );
  }
}
