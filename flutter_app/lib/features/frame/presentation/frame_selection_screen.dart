import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../domain/models/frame_model.dart';
import '../providers/frame_provider.dart';

/// Builds the full storage URL for a relative asset path.
String _storageUrl(String relativePath) {
  // Replace /api suffix with /storage/ for asset URLs
  final baseApi = AppConstants.apiBaseUrlDev;
  final storageBase = baseApi.replaceAll('/api', '/storage');
  return '$storageBase/$relativePath';
}

/// Frame Selection Screen — fetches frames from backend API.
class FrameSelectionScreen extends ConsumerStatefulWidget {
  const FrameSelectionScreen({super.key});

  @override
  ConsumerState<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends ConsumerState<FrameSelectionScreen> {
  FrameModel? _selectedFrame;

  void _onContinue() {
    if (_selectedFrame == null) return;
    ref.read(sessionNotifierProvider.notifier).setFrame(
      frameId: _selectedFrame!.id,
      poseCount: _selectedFrame!.poseCount,
    );
    context.go(AppRoutes.camera);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final remaining = sessionState.remainingTime;
    final timerText = '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final eventId = sessionState.session?.eventId ?? 1;
    final framesAsync = ref.watch(frameListProvider(eventId));

    return PhotoboothLayout(
      header: CustomerHeader(
        trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
      ),
      child: framesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                label: 'COBA LAGI',
                icon: Icons.refresh,
                onPressed: () => ref.invalidate(frameListProvider(eventId)),
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

          return Column(
            children: [
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pilih Frame Favoritmu', style: AppTextStyles.headlineLarge)
                        .animate().fadeIn(),
                    Text('${frames.length} pilihan', style: AppTextStyles.caption),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Text('Frame akan menghiasi hasil fotomu',
                    style: AppTextStyles.caption.copyWith(fontSize: 12.sp))
                    .animate().fadeIn(delay: 100.ms),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h, childAspectRatio: 0.75,
                    ),
                    itemCount: frames.length,
                    itemBuilder: (_, i) => _FrameCard(
                      frame: frames[i],
                      isSelected: _selectedFrame?.id == frames[i].id,
                      onTap: () => setState(() => _selectedFrame = frames[i]),
                    ).animate().fadeIn(delay: (i * 50).ms)
                        .scale(begin: const Offset(0.95, 0.95), delay: (i * 50).ms),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: ResponsiveButton(
                  label: 'MULAI FOTO', icon: Icons.camera_alt_rounded,
                  onPressed: _selectedFrame != null ? _onContinue : null,
                  width: double.infinity, height: 60.h,
                ).animate().fadeIn(delay: 400.ms),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({required this.frame, required this.isSelected, required this.onTap});
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
          color: isSelected ? AppColors.darkBrown : AppColors.creamWhite,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? AppColors.darkBrown : AppColors.borderWarm,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: isSelected ? 0.2 : 0.06),
            blurRadius: isSelected ? 8 : 4, offset: const Offset(2, 3),
          )],
        ),
        child: Column(
          children: [
            // Frame preview image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(9.r)),
                child: Container(
                  width: double.infinity,
                  // Checkerboard bg to show transparency
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEEEE),
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.none,
                      opacity: 0.05,
                    ),
                  ),
                  child: frame.assetUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _storageUrl(frame.assetUrl!),
                          fit: BoxFit.contain,
                          placeholder: (_, __) => Center(
                            child: SizedBox(
                              width: 24.r, height: 24.r,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image, size: 32.sp, color: AppColors.lightBrown),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.photo_size_select_actual, size: 32.sp, color: AppColors.lightBrown),
                        ),
                ),
              ),
            ),
            // Frame info
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Column(
                children: [
                  Text(
                    frame.name,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${frame.poseCount} foto',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? AppColors.creamWhite.withValues(alpha: 0.7) : AppColors.brown,
                      fontSize: 10.sp,
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(height: 4.h),
                    Icon(Icons.check_circle_rounded, color: AppColors.creamWhite, size: 18.sp),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
