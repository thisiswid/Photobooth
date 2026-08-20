import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
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
      header: const CustomerHeader(),
      child: framesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.darkBrown)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.brown),
              SizedBox(height: 12.h),
              Text('Gagal memuat frame', style: AppTextStyles.titleMedium),
              SizedBox(height: 8.h),
              Text(err.toString(), style: AppTextStyles.caption, textAlign: TextAlign.center),
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
        data: (frames) {
          // Auto-select first frame if none selected
          if (_selectedFrame == null && frames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedFrame = frames.first);
            });
          }

          final isMobile = context.isMobile;
          final isPortrait = context.isPortrait;

          if (isMobile || isPortrait) {
            // ── Mobile / Portrait Layout ────────────────────────────────────
            return Padding(
              padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilih Desain Bingkai', style: GoogleFonts.cormorantGaramond(fontSize: 22.sp, fontWeight: FontWeight.w800, color: AppColors.darkBrown)),
                          Text('Sentuh frame yang kamu sukai', style: AppTextStyles.caption.copyWith(fontSize: 10.5.sp)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Grid Frame (2 kolom di mobile)
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 3,
                        crossAxisSpacing: 10.w,
                        mainAxisSpacing: 10.h,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: frames.length,
                      itemBuilder: (_, i) {
                        final frame = frames[i];
                        final isSelected = _selectedFrame?.id == frame.id;
                        return _FrameCard(
                          frame: frame,
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedFrame = frame),
                        ).animate().fadeIn(delay: (i * 30).ms);
                      },
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: AppColors.creamWhite,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.gold, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkBrown.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 12.w),
                        SizedBox(
                          width: 150.w,
                          height: 44.h,
                          child: ResponsiveButton(
                            label: 'Mulai',
                            onPressed: _selectedFrame != null ? _onContinue : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Desktop & Tablet Landscape Layout ───────────────────────────
          return Row(
            children: [
              // ── Kiri (Flex: 3): Grid Katalog Frame Vintage ─────────────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 12.w, 12.h),
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
                              Text('Pilih Desain Bingkai', style: AppTextStyles.headlineLarge)
                                  .animate().fadeIn(),
                              SizedBox(height: 2.h),
                              Text('Pilih frame favorit untuk sesi pemotretanmu',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.brown))
                                  .animate().fadeIn(delay: 50.ms),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // Grid Kartu Frame Vintage
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12.w,
                            mainAxisSpacing: 12.h,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: frames.length,
                          itemBuilder: (_, i) {
                            final frame = frames[i];
                            final isSelected = _selectedFrame?.id == frame.id;
                            return _FrameCard(
                              frame: frame,
                              isSelected: isSelected,
                              onTap: () => setState(() => _selectedFrame = frame),
                            ).animate().fadeIn(delay: (i * 40).ms)
                             .scale(begin: const Offset(0.95, 0.95), delay: (i * 40).ms);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Garis Pemisah Vertikal Vintage
              Container(
                width: 1.2.w,
                margin: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.gold.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // ── Kanan (Flex: 2): Live Preview Frame Terpilih & Tombol Mulai ──
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 20.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 8.h),

                      // Frame Preview Widget
                      Expanded(
                        child: Center(
                          child: _selectedFrame != null
                              ? PhotoStripWidget(
                                  photos: const [],
                                  frame: _selectedFrame,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.paper,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: AppColors.borderWarm),
                                  ),
                                  child: Center(
                                    child: Text('Pilih frame dari kiri',
                                        style: AppTextStyles.caption),
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // Tombol Mulai
                      ResponsiveButton(
                        label: 'Mulai',
                        onPressed: _selectedFrame != null ? _onContinue : null,
                        width: double.infinity,
                        height: 48.h,
                      ).animate().fadeIn(delay: 200.ms),
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
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBrown.withValues(alpha: 0.04) : AppColors.creamWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.borderWarm,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.darkBrown.withValues(alpha: 0.04),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Thumbnail
              Expanded(
                child: Container(
                  color: AppColors.paper,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (frame.assetUrl != null && frame.assetUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: _storageUrl(frame.assetUrl!),
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image,
                                color: AppColors.lightBrown, size: 28.sp),
                          ),
                        )
                      else
                        Center(
                          child: Icon(Icons.photo_outlined,
                              color: AppColors.lightBrown, size: 32.sp),
                        ),

                      // Selected Checkmark Badge
                      if (isSelected)
                        Positioned(
                          top: 6.r,
                          right: 6.r,
                          child: Container(
                            padding: EdgeInsets.all(3.r),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check, size: 12.sp, color: AppColors.darkCoffee),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Frame Name & Pose Info
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                color: isSelected ? AppColors.darkBrown : AppColors.creamWhite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      frame.name,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      frame.slotCount > frame.poseCount
                          ? '${frame.poseCount} Pose • ${frame.slotCount} Slot'
                          : '${frame.poseCount} Pose',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9.sp,
                        color: isSelected
                            ? AppColors.creamWhite.withValues(alpha: 0.8)
                            : AppColors.brown.withValues(alpha: 0.7),
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
