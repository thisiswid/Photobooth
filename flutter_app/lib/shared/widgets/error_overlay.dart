import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'responsive_button.dart';

/// Full-screen friendly error overlay for hardware/network failures.
/// Shows a warm, non-technical message suitable for kiosk customers.
class ErrorOverlay extends StatelessWidget {
  const ErrorOverlay({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.icon = Icons.warning_amber_rounded,
    this.title = 'Oops!',
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlayDark,
      child: Center(
        child: Container(
          width: 480.w,
          padding: EdgeInsets.all(40.r),
          decoration: BoxDecoration(
            color: AppColors.surfaceModal,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AppColors.errorLight.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64.sp, color: AppColors.warningLight)
                  .animate()
                  .shake(duration: 600.ms),
              SizedBox(height: 20.h),
              Text(title, style: AppTextStyles.headlineMedium)
                  .animate()
                  .fadeIn(delay: 200.ms),
              SizedBox(height: 12.h),
              Text(
                message,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              SizedBox(height: 32.h),
              if (onRetry != null)
                ResponsiveButton(
                  label: 'Coba Lagi',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                  height: 64.h,
                ).animate().fadeIn(delay: 400.ms),
              if (onDismiss != null) ...[
                SizedBox(height: 12.h),
                ResponsiveButton(
                  label: 'Tutup',
                  onPressed: onDismiss,
                  variant: ButtonVariant.outlined,
                  height: 56.h,
                ).animate().fadeIn(delay: 500.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
