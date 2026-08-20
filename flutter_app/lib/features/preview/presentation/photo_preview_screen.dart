import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Screen 6 — Photo Preview with Frame.
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
      currentStep: 3,
      header: CustomerHeader(
        currentStep: 3,
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.creamWhite,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.gold, width: 1.2),
                  ),
                  child: Text(
                    '${photos.length} / ${sessionState.totalPoses} Foto Siap',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.darkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Periksa hasil fotomu di dalam bingkai sebelum memilih filter efek',
                style: AppTextStyles.caption.copyWith(color: AppColors.brown),
              ).animate().fadeIn(delay: 200.ms),
            ),
          ),
          SizedBox(height: 12.h),

          // ── Photo Strip with Frame ───────────────────────────────────
          Expanded(
            child: photos.isEmpty
                ? const _EmptyPhotos()
                : Center(
                    child: PhotoStripWidget(
                      photos: photos,
                      frame: sessionState.selectedFrame,
                    ),
                  ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Row(
              children: [
                Expanded(
                  child: ResponsiveButton(
                    label: 'AMBIL ULANG SEMUA',
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
                    label: 'LANJUT PILIH FILTER',
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
