import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/print_furniture.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../domain/models/frame_model.dart';
import '../providers/frame_provider.dart';

/// Builds the full storage URL for a relative asset path.
String _storageUrl(String relativePath) {
  if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
    return relativePath;
  }
  String clean = relativePath;
  if (clean.startsWith('/')) clean = clean.substring(1);
  if (clean.startsWith('storage/')) clean = clean.substring('storage/'.length);
  final baseApi = AppConstants.apiBaseUrlDev;
  final storageBase = baseApi.replaceAll('/api', '/storage');
  return '$storageBase/$clean';
}

/// Frame Selection Screen — split view with event categories and large preview on right.
class FrameSelectionScreen extends ConsumerStatefulWidget {
  const FrameSelectionScreen({super.key});

  @override
  ConsumerState<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends ConsumerState<FrameSelectionScreen> {
  FrameModel? _selectedFrame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionNotifierProvider.notifier).ensureSessionStarted();
    });
  }

  void _onContinue() {
    if (_selectedFrame == null) return;
    final frame = _selectedFrame!;

    // For double strips, actual pose count is half the slot count
    // double_6 = 3 poses, double_8 = 4 poses, single = poseCount as-is
    final int actualPoseCount = switch (frame.layoutType) {
      'double_6' => 3,
      'double_8' => 4,
      _ => frame.poseCount,
    };

    ref.read(sessionNotifierProvider.notifier).setFrame(
      frameId: frame.id,
      poseCount: actualPoseCount,
      frameModel: frame,
    );
    context.go(AppRoutes.camera);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final eventId = sessionState.session?.eventId ?? 1;
    final framesAsync = ref.watch(frameListProvider(eventId));

    return PhotoboothLayout(
      child: framesAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2.5),
              ),
              SizedBox(height: 16.h),
              Text(
                'Memuat Koleksi Bingkai...',
                style: AppFonts.display(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.paperBright,
              border: Border.all(color: AppColors.inkOxide, width: AppGeometry.hairline),
            ),
            child: Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.inkOxideLit, width: AppGeometry.hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 40.sp, color: AppColors.inkOxide),
                  SizedBox(height: 12.h),
                  Text(
                    'Gagal Memuat Bingkai',
                    style: AppFonts.display(fontSize: 20.sp, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    err.toString(),
                    style: AppFonts.ui(fontSize: 11.sp, color: AppColors.ink70),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  ResponsiveButton(
                    label: 'Coba Lagi',
                    onPressed: () {
                      ErrorLogger.instance.logRetryAttempt(
                        action: 'Muat Ulang Frame',
                        attempt: 1,
                        reason: err.toString(),
                      );
                      ref.invalidate(frameListProvider(eventId));
                    },
                    width: 200.w,
                    height: 48.h,
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (frames) {
          // Auto-select first frame if none selected
          if (_selectedFrame == null && frames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedFrame = frames.first);
            });
          }

          final isMobile = context.isMobile;
          final isPortrait = context.isPortrait;
          final isCompact = isMobile || isPortrait;

          if (isCompact) {
            // ── Mobile / Portrait Layout ────────────────────────────────────
            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PILIH BINGKAI FOTO',
                            style: AppFonts.display(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Sentuh desain frame favoritmu',
                            style: AppFonts.ui(fontSize: 11.sp, color: AppColors.ink70),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppColors.paperDeep,
                          border: Border.all(color: AppColors.ink15, width: 1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '${frames.length} OPSI',
                          style: AppFonts.ui(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Container(height: AppGeometry.hairline, color: AppColors.ink15),
                ),
                SizedBox(height: 8.h),

                // Grid Frame
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : 3,
                      crossAxisSpacing: 10.w,
                      mainAxisSpacing: 10.h,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: frames.length,
                    itemBuilder: (_, i) {
                      final frame = frames[i];
                      final isSelected = _selectedFrame?.id == frame.id;
                      return _FrameCard(
                        frame: frame,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedFrame = frame),
                      ).animate().fadeIn(delay: (i * 25).ms);
                    },
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.paperBright,
                    border: const Border(top: BorderSide(color: AppColors.ink15, width: 1)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedFrame?.name ?? 'Pilih Frame',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.display(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if (_selectedFrame != null)
                              Text(
                                _selectedFrame!.slotCount > _selectedFrame!.poseCount
                                    ? '${_selectedFrame!.poseCount} Pose • ${_selectedFrame!.slotCount} Slot'
                                    : '${_selectedFrame!.poseCount} Pose',
                                style: AppFonts.ui(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.spot,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      SizedBox(
                        width: 130.w,
                        child: ResponsiveButton(
                          label: 'Mulai',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _selectedFrame != null ? _onContinue : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // ── Desktop & Tablet Landscape Layout ───────────────────────────
          return Row(
            children: [
              // ── Kiri (Flex: 3): Grid Katalog Frame Cetak ───────────────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 16.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PILIH BINGKAI FOTO',
                                style: AppFonts.display(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                'Sentuh desain bingkai favoritmu untuk sesi ini',
                                style: AppFonts.ui(
                                  fontSize: 11.5.sp,
                                  color: AppColors.ink70,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.paperDeep,
                              border: Border.all(color: AppColors.ink15, width: 1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '${frames.length} PILIHAN',
                              style: AppFonts.ui(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10.h),
                      Container(height: AppGeometry.hairline, color: AppColors.ink),
                      SizedBox(height: 12.h),

                      // Grid Kartu Frame
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12.w,
                            mainAxisSpacing: 12.h,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: frames.length,
                          itemBuilder: (_, i) {
                            final frame = frames[i];
                            final isSelected = _selectedFrame?.id == frame.id;
                            return _FrameCard(
                              frame: frame,
                              isSelected: isSelected,
                              onTap: () => setState(() => _selectedFrame = frame),
                            ).animate().fadeIn(delay: (i * 35).ms);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Garis Pemisah Vertikal Hairline
              Container(
                width: AppGeometry.hairline,
                color: AppColors.ink15,
              ),

              // ── Kanan (Flex: 2): Live Preview Frame Terpilih & Tombol Mulai ──
              Expanded(
                flex: 2,
                child: Container(
                  color: AppColors.paperDeep,
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 20.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'PRATINJAU CETAK',
                          style: AppFonts.ui(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink40,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),

                      // Frame Preview Widget
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.paperBright,
                              border: Border.all(color: AppColors.ink15, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _selectedFrame != null
                                ? PhotoStripWidget(
                                    photos: const [],
                                    frame: _selectedFrame,
                                  )
                                : Center(
                                    child: Text(
                                      'Pilih bingkai di samping',
                                      style: AppFonts.ui(color: AppColors.ink40),
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // Detail Frame Card
                      if (_selectedFrame != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: AppColors.paperBright,
                            border: Border.all(color: AppColors.ink15, width: 1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFrame!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.display(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    'Format Foto',
                                    style: AppFonts.ui(fontSize: 11.sp, color: AppColors.ink70),
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: const DotLeader(color: AppColors.ink15),
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    _selectedFrame!.slotCount > _selectedFrame!.poseCount
                                        ? '${_selectedFrame!.poseCount} Pose (${_selectedFrame!.slotCount} Slot)'
                                        : '${_selectedFrame!.poseCount} Pose',
                                    style: AppFonts.ui(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.spot,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Tombol Mulai
                      ResponsiveButton(
                        label: 'Mulai Pemotretan',
                        icon: Icons.camera_alt_rounded,
                        onPressed: _selectedFrame != null ? _onContinue : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.frame,
    required this.isSelected,
    required this.onTap,
  });

  final FrameModel frame;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.paperBright,
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.ink15,
            width: isSelected ? 2.0 : AppGeometry.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.ink.withValues(alpha: 0.12)
                  : AppColors.ink.withValues(alpha: 0.03),
              blurRadius: isSelected ? 10 : 3,
              offset: isSelected ? const Offset(0, 4) : const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.spot : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Thumbnail Area
              Expanded(
                child: Container(
                  color: AppColors.paperDeep,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (frame.assetUrl != null && frame.assetUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: _storageUrl(frame.assetUrl!),
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink40),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: AppColors.ink40, size: 28),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(Icons.photo_outlined, color: AppColors.ink40, size: 32),
                        ),

                      // Selected Badge (Stamp Style)
                      if (isSelected)
                        Positioned(
                          top: 6.r,
                          right: 6.r,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.spot,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 10.sp, color: AppColors.paperBright),
                                SizedBox(width: 2.w),
                                Text(
                                  'PILIHAN',
                                  style: AppFonts.ui(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.paperBright,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Frame Name & Pose Info
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                color: isSelected ? AppColors.ink : AppColors.paperBright,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      frame.name,
                      style: AppFonts.display(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.paperBright : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      frame.slotCount > frame.poseCount
                          ? '${frame.poseCount} Pose · ${frame.slotCount} Slot'
                          : '${frame.poseCount} Pose',
                      style: AppFonts.ui(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.paper : AppColors.ink70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
