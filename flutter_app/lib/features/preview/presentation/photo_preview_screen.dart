import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../features/session/domain/models/session_model.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Screen 6 — Photo Preview grid.
/// CustomerHeader + warm parchment bg + per-photo retake.
class PhotoPreviewScreen extends ConsumerWidget {
  const PhotoPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final photos = sessionState.session?.photos ?? [];
    final remaining = sessionState.remainingTime;
    final timerText =
        '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return PhotoboothLayout(
      header: CustomerHeader(
        trailing: TimerChip(
          text: timerText,
          isWarning: remaining.inSeconds < 60,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hasil Fotomu', style: AppTextStyles.headlineMedium)
                    .animate().fadeIn(duration: 400.ms),
                Text(
                  '${photos.length} / ${sessionState.totalPoses} foto',
                  style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.darkBrown),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              'Ketuk foto untuk melihat atau ambil ulang (maks. 2x per foto)',
              style: AppTextStyles.bodySmall,
            ).animate().fadeIn(delay: 200.ms),
          ),
          SizedBox(height: 12.h),

          // ── Photo grid ────────────────────────────────────────────────
          Expanded(
            child: photos.isEmpty
                ? const _EmptyPhotos()
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: _PhotoGrid(photos: photos, ref: ref),
                  ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Row(
              children: [
                Expanded(
                  child: ResponsiveButton(
                    label: 'Ambil Ulang Semua',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      ref.read(sessionNotifierProvider.notifier).resetSession();
                      context.go(AppRoutes.camera);
                    },
                    variant: ButtonVariant.outlined,
                    height: 52.h,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 2,
                  child: ResponsiveButton(
                    label: 'PILIH FILTER',
                    icon: Icons.tune_rounded,
                    onPressed: sessionState.allPosesDone
                        ? () => context.go(AppRoutes.filter)
                        : null,
                    height: 52.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo Grid ────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.ref});
  final List<PhotoModel> photos;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        ResponsiveHelper.gridColumns(context, small: 2, medium: 2, large: 4);
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 4 / 3,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => _PhotoThumbnail(
        photo: photos[i],
        index: i,
        retakeCount: ref.read(sessionNotifierProvider).session?.photos[i].retakeCount ?? 0,
        canRetake: ref.read(sessionNotifierProvider).session?.canRetakePose(i) ?? true,
        onRetake: () => context.go(AppRoutes.camera, extra: {'retakeIndex': i}),
      ).animate()
          .fadeIn(delay: (i * 80).ms)
          .scale(begin: const Offset(0.95, 0.95), delay: (i * 80).ms),
    );
  }
}

// ── Photo Thumbnail ───────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.index,
    required this.retakeCount,
    required this.canRetake,
    required this.onRetake,
  });

  final PhotoModel photo;
  final int index;
  final int retakeCount;
  final bool canRetake;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canRetake ? onRetake : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.borderWarm, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBrown.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.asset(
                photo.fileUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.photo,
                      color: AppColors.lightBrown, size: 32.sp),
                ),
              ),
            ),
            // Retake badge
            Positioned(
              top: 6.r,
              right: 6.r,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: canRetake ? AppColors.darkBrown : AppColors.lightBrown.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  canRetake ? 'Retake' : 'Limit',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.creamWhite,
                  ),
                ),
              ),
            ),
            // Retake count
            Positioned(
              bottom: 6.r,
              left: 6.r,
              child: Text(
                'Retake: $retakeCount/2',
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.creamWhite,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined,
              size: 64.sp, color: AppColors.lightBrown),
          SizedBox(height: 16.h),
          Text('Belum ada foto', style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }
}
