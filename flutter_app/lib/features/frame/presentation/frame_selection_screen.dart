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
import '../../../shared/widgets/responsive_button.dart';

class FrameOption {
  const FrameOption({required this.id, required this.name, required this.color, this.description});
  final String id;
  final String name;
  final Color color;
  final String? description;
}

const _mockFrames = [
  FrameOption(id: 'classic_gold',  name: 'Classic Gold',  color: Color(0xFFC89B5B), description: 'Elegan & timeless'),
  FrameOption(id: 'coffee_brown',  name: 'Coffee Brown',  color: Color(0xFF5C3A21), description: 'Warm coffee vibes'),
  FrameOption(id: 'midnight',      name: 'Midnight',      color: Color(0xFF1A1A2E), description: 'Dark & mysterious'),
  FrameOption(id: 'rose_gold',     name: 'Rose Gold',     color: Color(0xFFB76E79), description: 'Soft & romantic'),
  FrameOption(id: 'forest',        name: 'Forest',        color: Color(0xFF2D6A4F), description: 'Nature fresh'),
  FrameOption(id: 'minimal',       name: 'Minimal White', color: Color(0xFFF8F8F8), description: 'Clean & simple'),
];

/// Frame Selection — header transparan centered 2x.
class FrameSelectionScreen extends ConsumerStatefulWidget {
  const FrameSelectionScreen({super.key});

  @override
  ConsumerState<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends ConsumerState<FrameSelectionScreen> {
  String _selectedId = _mockFrames.first.id;

  void _onContinue() {
    ref.read(sessionNotifierProvider.notifier).setFrame(frameId: 1, poseCount: 4);
    context.go(AppRoutes.camera);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(sessionNotifierProvider).remainingTime;
    final timerText = '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return PhotoboothLayout(
      header: CustomerHeader(
        trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
      ),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pilih Frame Favoritmu', style: AppTextStyles.headlineLarge)
                    .animate().fadeIn(),
                Text('${_mockFrames.length} pilihan', style: AppTextStyles.caption),
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
                  mainAxisSpacing: 12.h, childAspectRatio: 1.15,
                ),
                itemCount: _mockFrames.length,
                itemBuilder: (_, i) => _FrameCard(
                  frame: _mockFrames[i],
                  isSelected: _mockFrames[i].id == _selectedId,
                  onTap: () => setState(() => _selectedId = _mockFrames[i].id),
                ).animate().fadeIn(delay: (i * 50).ms)
                    .scale(begin: const Offset(0.95, 0.95), delay: (i * 50).ms),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: ResponsiveButton(
              label: 'MULAI FOTO', icon: Icons.camera_alt_rounded,
              onPressed: _onContinue, width: double.infinity, height: 60.h,
            ).animate().fadeIn(delay: 400.ms),
          ),
        ],
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({required this.frame, required this.isSelected, required this.onTap});
  final FrameOption frame;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(12.r),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36.r, height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: frame.color,
                border: Border.all(
                  color: isSelected ? AppColors.creamWhite.withValues(alpha: 0.5) : AppColors.borderWarm,
                  width: 1.5,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(frame.name,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (frame.description != null) ...[
              SizedBox(height: 2.h),
              Text(frame.description!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.creamWhite.withValues(alpha: 0.7) : AppColors.brown,
                  fontSize: 10.sp,
                ),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (isSelected) ...[
              SizedBox(height: 6.h),
              Icon(Icons.check_circle_rounded, color: AppColors.creamWhite, size: 18.sp),
            ],
          ],
        ),
      ),
    );
  }
}
