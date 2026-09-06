import 'dart:async';
import 'dart:io' as dart_io;
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/services/photo_upload_prep_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../core/theme/booth_material.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/printer_settings_modal.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

enum PrintUiStatus {
  idle,
  preparing,
  printing,
  success,
  failed,
}

/// Final Result Screen — Redesigned with the Darkroom Editorial design system.
/// Displays print preview / boomerang motion, editorial QR ticket card,
/// real-time printer status, and finish action.
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  PrintUiStatus _printStatus = PrintUiStatus.idle;
  String _printStatusMessage = '';
  bool _hasAutoPrinted = false;
  bool _isPrinting = false;

  static const Duration _qrGraceDuration = Duration(seconds: 20);
  bool _qrWaitExpired = false;
  Timer? _qrGraceTimer;
  Timer? _autoResetTimer;
  bool _showPrintOverlay = false;

  @override
  void initState() {
    super.initState();
    _triggerBackendGenerationAndAutoPrint();
    _qrGraceTimer = Timer(_qrGraceDuration, () {
      if (mounted) setState(() => _qrWaitExpired = true);
    });

    final tenant = ref.read(tenantNotifierProvider).valueOrNull;
    final resultTimeout = tenant?.timers.resultScreenTimeoutSeconds ?? 60;
    _autoResetTimer = Timer(Duration(seconds: resultTimeout), () {
      if (mounted) _finishSession();
    });
  }

  @override
  void dispose() {
    _qrGraceTimer?.cancel();
    _autoResetTimer?.cancel();
    PhotoUploadPrepService.instance.clear();
    super.dispose();
  }

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
      _printStatusMessage = 'Menyiapkan master cetak resolusi tinggi...';
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

      final paths = session.photos.map((p) => p.fileUrl).toList();
      final prepared = await PhotoUploadPrepService.instance.bytesForAll(paths);

      for (int i = 0; i < session.photos.length; i++) {
        final path = paths[i];
        final file = dart_io.File(path);
        if (await file.exists()) {
          final small = prepared[i];
          formData.files.add(MapEntry(
            'photos[]',
            small != null
                ? dio_pkg.MultipartFile.fromBytes(
                    small,
                    filename: 'pose_${i + 1}.jpg',
                  )
                : await dio_pkg.MultipartFile.fromFile(
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

    if (!_hasAutoPrinted && mounted) {
      final autoPrintEnabled = await PrinterService.getAutoPrint();
      if (autoPrintEnabled) {
        _hasAutoPrinted = true;
        await _executePrint(finalUrl: generatedFinalUrl);
      } else {
        debugPrint('ℹ️ Auto-print dimatikan di settings — menunggu cetak manual.');
        if (mounted) {
          setState(() {
            _printStatus = PrintUiStatus.idle;
            _printStatusMessage = 'Auto-print dimatikan. Tekan tombol cetak bila perlu.';
          });
        }
      }
    }
  }

  /// Eksekusi pengiriman print ke Epson L8050 — hanya 1x cetak per panggilan.
  Future<void> _executePrint({String? finalUrl}) async {
    if (!mounted) return;
    // Cegah print ganda / bersamaan
    if (_isPrinting) {
      debugPrint('⚠️ Print sudah berjalan, skip duplikat');
      return;
    }
    _isPrinting = true;

    setState(() {
      _printStatus = PrintUiStatus.printing;
      _printStatusMessage = 'Mengirim data ke printer Epson L8050...';
      _showPrintOverlay = true; // Tampilkan overlay fullscreen
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
    } finally {
      _isPrinting = false;
      if (mounted) {
        setState(() => _showPrintOverlay = false); // Sembunyikan overlay
      }
    }
  }

  void _finishSession() {
    _autoResetTimer?.cancel();
    final session = ref.read(sessionNotifierProvider).session;
    if (session != null) {
      DioClient.instance.dio.post('/sessions/${session.sessionId}/finish').catchError((e) {
        debugPrint('Failed to mark session as finished: $e');
        return dio_pkg.Response(requestOptions: dio_pkg.RequestOptions(path: ''));
      });
    }
    ref.read(sessionNotifierProvider.notifier).resetSession();
    if (mounted) context.go(AppRoutes.welcome);
  }

  bool _showMotionPreview = false;

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final session = sessionState.session;
    final photos = session?.photos ?? [];
    final frame = sessionState.selectedFrame;

    final qrToken = session?.qrToken;
    final hasQrToken = qrToken != null && qrToken.trim().isNotEmpty;
    final qrUrl = hasQrToken ? '${AppConstants.resultBaseUrl}/$qrToken' : null;

    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final isCompact = isMobile || isPortrait;

    final finalUrl = session?.finalUrl;
    final hasFinalUrl = finalUrl != null && finalUrl.trim().isNotEmpty;
    final tenant = ref.watch(tenantNotifierProvider).valueOrNull;
    final tenantName = tenant?.cafe.name ?? AppConstants.defaultCafeBrandName;

    return Stack(
      children: [
        PhotoboothLayout(
          material: BoothMaterial.paper,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ambient watermark & crop marks
              _ResultBackground(isCompact: isCompact),

              // Main Body Content
              isCompact
                  ? _buildCompactLayout(
                      context,
                      sessionState,
                      photos,
                      frame,
                      hasFinalUrl,
                      finalUrl,
                      qrUrl,
                      hasQrToken,
                      tenantName,
                    )
                  : _buildLandscapeLayout(
                      context,
                      sessionState,
                      photos,
                      frame,
                      hasFinalUrl,
                      finalUrl,
                      qrUrl,
                      hasQrToken,
                      tenantName,
                    ),
            ],
          ),
        ),

        // Fullscreen Processing Overlay when printing
        if (_showPrintOverlay) _buildPrintingOverlay(),
      ],
    );
  }

  // ── Desktop / Landscape / Kiosk Layout ────────────────────────────────────

  Widget _buildLandscapeLayout(
    BuildContext context,
    SessionState sessionState,
    List<PhotoModel> photos,
    dynamic frame,
    bool hasFinalUrl,
    String? finalUrl,
    String? qrUrl,
    bool hasQrToken,
    String tenantName,
  ) {
    return Row(
      children: [
        // ── Kiri (Flex: 6): Large Framed Photo Strip / Boomerang Preview ───
        Expanded(
          flex: 6,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 16.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top control bar: Segmented switch centered, icon only
                Center(
                  child: Container(
                    padding: EdgeInsets.all(3.r),
                    decoration: BoxDecoration(
                      color: AppColors.paperDeep,
                      border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                      borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SegmentTab(
                          icon: Icons.photo_library_outlined,
                          isSelected: !_showMotionPreview,
                          onTap: () => setState(() => _showMotionPreview = false),
                        ),
                        _SegmentTab(
                          icon: Icons.movie_creation_outlined,
                          isSelected: _showMotionPreview,
                          onTap: () => setState(() => _showMotionPreview = true),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10.h),
                Container(height: AppGeometry.hairline, color: AppColors.ink15),
                SizedBox(height: 10.h),

                // Main Stage: Large Photo Strip or Motion Player
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.paperBright,
                        border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.10),
                            blurRadius: AppGeometry.stripShadowBlur,
                            offset: const Offset(0, AppGeometry.stripShadowY),
                          ),
                        ],
                      ),
                      child: !_showMotionPreview
                          ? (hasFinalUrl
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(2.r),
                                  child: Image.network(
                                    _getStorageUrl(finalUrl!),
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.ink,
                                          strokeWidth: 2,
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => PhotoStripWidget(
                                      photos: photos,
                                      frame: frame,
                                      colorFilter: sessionState.selectedFilter?.colorFilter,
                                    ),
                                  ),
                                )
                              : PhotoStripWidget(
                                  photos: photos,
                                  frame: frame,
                                  colorFilter: sessionState.selectedFilter?.colorFilter,
                                ))
                          : _MotionPlayerWidget(
                              photos: photos,
                              colorFilter: sessionState.selectedFilter?.colorFilter,
                              tenantName: tenantName,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Hairline Divider
        Container(
          width: AppGeometry.hairline,
          color: AppColors.ink15,
        ),

        // ── Kanan (Flex: 5): Full Height QR Download Card + Actions ─────────
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.paperDeep,
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 20.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // QR Digital Download Ticket Card (Mengisi ruang secara dominan)
                Expanded(
                  child: _EditorialQrTicket(
                    qrUrl: qrUrl,
                    isFullHeight: true,
                  ),
                ),
                SizedBox(height: 10.h),

                // Real-time Printer Status Banner (Kecil & Rapi di bawah)
                _buildPrintStatusWidget(context),
                SizedBox(height: 10.h),

                // Action Button: Selesai (Locked until QR ready or grace period expired)
                _buildFinishButton(
                  isMobile: false,
                  hasQr: hasQrToken,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Compact / Mobile / Portrait Layout ────────────────────────────────────

  Widget _buildCompactLayout(
    BuildContext context,
    SessionState sessionState,
    List<PhotoModel> photos,
    dynamic frame,
    bool hasFinalUrl,
    String? finalUrl,
    String? qrUrl,
    bool hasQrToken,
    String tenantName,
  ) {
    return Column(
      children: [
        // Sub-Header: Centered Icon-only Toggle
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
          child: Center(
            child: Container(
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                color: AppColors.paperDeep,
                border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SegmentTab(
                    icon: Icons.photo_library_outlined,
                    isSelected: !_showMotionPreview,
                    isCompact: true,
                    onTap: () => setState(() => _showMotionPreview = false),
                  ),
                  _SegmentTab(
                    icon: Icons.movie_creation_outlined,
                    isSelected: _showMotionPreview,
                    isCompact: true,
                    onTap: () => setState(() => _showMotionPreview = true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(height: AppGeometry.hairline, color: AppColors.ink15),
        ),

        // Scrollable Body for Mobile
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Column(
              children: [
                // Preview Box
                Container(
                  height: 380.h,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.paperBright,
                    border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: !_showMotionPreview
                        ? (hasFinalUrl
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(2.r),
                                child: Image.network(
                                  _getStorageUrl(finalUrl!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => PhotoStripWidget(
                                    photos: photos,
                                    frame: frame,
                                    colorFilter: sessionState.selectedFilter?.colorFilter,
                                  ),
                                ),
                              )
                            : PhotoStripWidget(
                                photos: photos,
                                frame: frame,
                                colorFilter: sessionState.selectedFilter?.colorFilter,
                              ))
                        : _MotionPlayerWidget(
                            photos: photos,
                            colorFilter: sessionState.selectedFilter?.colorFilter,
                            tenantName: tenantName,
                          ),
                  ),
                ),
                SizedBox(height: 12.h),

                // QR Card
                _EditorialQrTicket(qrUrl: qrUrl, isCompact: true),
                SizedBox(height: 10.h),

                // Printer Status Widget
                _buildPrintStatusWidget(context),
                SizedBox(height: 10.h),

                // Tombol Selesai
                _buildFinishButton(
                  isMobile: true,
                  hasQr: hasQrToken,
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tombol Selesai ────────────────────────────────────────────────────────

  Widget _buildFinishButton({required bool isMobile, required bool hasQr}) {
    final unlocked = hasQr || _qrWaitExpired;

    return ResponsiveButton(
      label: unlocked ? '' : 'Menyiapkan...',
      icon: unlocked ? Icons.check_rounded : null,
      isLoading: !unlocked,
      width: double.infinity,
      onPressed: unlocked ? _finishSession : null,
    );
  }

  // ── Status Cetak Widget ───────────────────────────────────────────────────

  Widget _buildPrintStatusWidget(BuildContext context) {
    switch (_printStatus) {
      case PrintUiStatus.preparing:
      case PrintUiStatus.printing:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.paperBright,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
            border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16.r,
                height: 16.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  _printStatusMessage.isNotEmpty ? _printStatusMessage : 'Sedang memproses master cetak...',
                  style: AppFonts.ui(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn();

      case PrintUiStatus.success:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.paperBright,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
            border: Border.all(color: AppColors.inkGreen, width: 1.0),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.inkGreen, size: 18.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Silakan ambil hasil cetakan foto Anda!',
                  style: AppFonts.ui(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkGreen,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn();

      case PrintUiStatus.failed:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.paperBright,
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
            border: Border.all(color: AppColors.inkOxide, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.inkOxide, size: 18.r),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _printStatusMessage.isNotEmpty
                          ? _printStatusMessage
                          : 'Gagal mencetak otomatis.',
                      style: AppFonts.ui(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkOxide,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => PrinterSettingsModal.show(
                      context,
                      onPrinterConfigured: () {},
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_rounded, size: 12.r, color: AppColors.inkOxide),
                          SizedBox(width: 4.w),
                          Text(
                            'PILIH PRINTER / CEK KONEKSI',
                            style: AppFonts.ui(
                              color: AppColors.inkOxide,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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

  // ── Fullscreen Overlay saat Cetak Berlangsung ──────────────────────────────

  Widget _buildPrintingOverlay() {
    return Positioned.fill(
      child: Material(
        color: AppColors.bench.withValues(alpha: 0.94),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(28.r),
            decoration: BoxDecoration(
              color: AppColors.benchRaised,
              border: Border.all(color: AppColors.benchLine, width: AppGeometry.hairline),
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 52.r,
                  height: 52.r,
                  child: const CircularProgressIndicator(
                    color: AppColors.light,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'SEDANG MENCETAK FOTO',
                  style: AppFonts.display(
                    color: AppColors.light,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Mohon tunggu, berkas sedang diproses oleh printer studio...',
                  style: AppFonts.ui(
                    color: AppColors.light60,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Segment Tab Switcher ────────────────────────────────────────────────────

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12.w : 16.w,
          vertical: isCompact ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Icon(
          icon,
          size: isCompact ? 16.sp : 18.sp,
          color: isSelected ? AppColors.paperBright : AppColors.ink,
        ),
      ),
    );
  }
}

// ── Editorial QR Ticket Card (Simple & Prominent QR Box) ─────────────────────

class _EditorialQrTicket extends StatelessWidget {
  const _EditorialQrTicket({
    this.qrUrl,
    this.isCompact = false,
    this.isFullHeight = false,
  });

  final String? qrUrl;
  final bool isCompact;
  final bool isFullHeight;

  @override
  Widget build(BuildContext context) {
    final qrReady = qrUrl != null && qrUrl!.isNotEmpty;
    // Di layar landscape full height, ukuran QR diperbesar menjadi 240-270r
    final qrSize = isFullHeight ? 250.r : (isCompact ? 170.r : 210.r);

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isFullHeight ? 20.w : 16.w,
        vertical: isFullHeight ? 18.h : 14.h,
      ),
      child: Column(
        mainAxisSize: isFullHeight ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: isFullHeight ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          // White container for QR Code (High contrast & Large)
          Container(
            width: qrSize,
            height: qrSize,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.ink, width: 1.8),
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: qrReady
                ? QrImageView(
                    data: qrUrl!,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.ink,
                    ),
                    padding: EdgeInsets.zero,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32.r,
                          height: 32.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'Membuat QR...',
                          style: AppFonts.ui(
                            fontSize: 11.sp,
                            color: AppColors.ink70,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: isFullHeight ? 16.h : 10.h),

          // Simple & Direct Instruction Text
          Text(
            'Scan untuk download foto & video ke HP',
            textAlign: TextAlign.center,
            style: AppFonts.ui(
              fontSize: isFullHeight ? 13.sp : 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: isFullHeight ? 12.h : 8.h),

          // Powered by SnapTech
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10.w, height: 1, color: AppColors.ink15),
              SizedBox(width: 6.w),
              Text(
                'POWERED BY SNAPTECH',
                style: AppFonts.ui(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink40,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(width: 6.w),
              Container(width: 10.w, height: 1, color: AppColors.ink15),
            ],
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperBright,
        border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Centered SCAN ME badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: const BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.spot,
                  borderRadius: BorderRadius.circular(3.r),
                ),
                child: Text(
                  'SCAN ME',
                  style: AppFonts.ui(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.paperBright,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // QR Code Body
          if (isFullHeight)
            Expanded(child: Center(child: SingleChildScrollView(child: content)))
          else
            content,
        ],
      ),
    );
  }
}

// ── Motion Player (Boomerang Loop) ──────────────────────────────────────────

class _MotionPlayerWidget extends StatefulWidget {
  const _MotionPlayerWidget({
    required this.photos,
    this.colorFilter,
    this.tenantName,
  });

  final List<dynamic> photos;
  final ColorFilter? colorFilter;
  final String? tenantName;

  @override
  State<_MotionPlayerWidget> createState() => _MotionPlayerWidgetState();
}

class _MotionPlayerWidgetState extends State<_MotionPlayerWidget> {
  Timer? _loopTimer;
  int _currentSeqIndex = 0;
  List<int> _sequence = [];

  @override
  void initState() {
    super.initState();
    _buildSequence();
    _startAnimationLoop();
  }

  void _buildSequence() {
    final count = widget.photos.length;
    if (count == 0) return;
    _sequence = [];
    for (int i = 0; i < count; i++) {
      _sequence.add(i);
    }
    if (count > 2) {
      for (int i = count - 2; i > 0; i--) {
        _sequence.add(i);
      }
    }
  }

  void _startAnimationLoop() {
    if (_sequence.isEmpty) return;
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentSeqIndex = (_currentSeqIndex + 1) % _sequence.length;
      });
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: AppColors.bench,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
        ),
        child: Center(
          child: Text(
            'Foto belum tersedia untuk animasi motion.',
            style: AppFonts.ui(color: AppColors.paperBright),
          ),
        ),
      );
    }

    final photoIdx = _sequence.isNotEmpty ? _sequence[_currentSeqIndex] : 0;
    final photo = widget.photos[photoIdx.clamp(0, widget.photos.length - 1)];
    final path = (photo is String) ? photo : (photo.fileUrl as String);

    Widget imageWidget;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      final file = dart_io.File(path);
      imageWidget = file.existsSync()
          ? Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              color: AppColors.bench,
              child: const Icon(Icons.broken_image, color: AppColors.paperDeep),
            );
    }

    if (widget.colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: widget.colorFilter!,
        child: imageWidget,
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bench,
          border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          child: imageWidget,
        ),
      ),
    );
  }
}

// ── Background Ambient Watermark & Registration Marks ────────────────────────

class _ResultBackground extends StatelessWidget {
  const _ResultBackground({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Watermark cap stempel lab film
          Positioned(
            right: isCompact ? 12.w : 36.w,
            bottom: isCompact ? 12.h : 28.h,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: -0.06,
                child: Text(
                  '★ ARCHIVE LAB GRADE ★ 300 DPI MASTER',
                  style: AppFonts.display(
                    fontSize: isCompact ? 28.sp : 44.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 3.5,
                  ),
                ),
              ),
            ),
          ),

          // 4-Corner Hairline Crop Marks
          Positioned(
            top: 10.h,
            left: 12.w,
            child: const _HairlineCropMark(corner: _CropCorner.topLeft),
          ),
          Positioned(
            top: 10.h,
            right: 12.w,
            child: const _HairlineCropMark(corner: _CropCorner.topRight),
          ),
          Positioned(
            bottom: 10.h,
            left: 12.w,
            child: const _HairlineCropMark(corner: _CropCorner.bottomLeft),
          ),
          Positioned(
            bottom: 10.h,
            right: 12.w,
            child: const _HairlineCropMark(corner: _CropCorner.bottomRight),
          ),
        ],
      ),
    );
  }
}

enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class _HairlineCropMark extends StatelessWidget {
  const _HairlineCropMark({required this.corner});
  final _CropCorner corner;

  @override
  Widget build(BuildContext context) {
    const double markSize = 14.0;
    const double lineW = 1.0;
    const color = AppColors.ink15;

    return SizedBox(
      width: markSize,
      height: markSize,
      child: CustomPaint(
        painter: _CropMarkPainter(corner: corner, color: color, strokeWidth: lineW),
      ),
    );
  }
}

class _CropMarkPainter extends CustomPainter {
  const _CropMarkPainter({
    required this.corner,
    required this.color,
    required this.strokeWidth,
  });

  final _CropCorner corner;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    switch (corner) {
      case _CropCorner.topLeft:
        canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
        canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
        break;
      case _CropCorner.topRight:
        canvas.drawLine(Offset(size.width, 0), const Offset(0, 0), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
        break;
      case _CropCorner.bottomLeft:
        canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
        canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
        break;
      case _CropCorner.bottomRight:
        canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CropMarkPainter old) =>
      old.corner != corner || old.color != color;
}
