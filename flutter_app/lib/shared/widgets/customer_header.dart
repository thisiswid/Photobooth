import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reusable internal page header — TRANSPARAN, logo + brand CENTER, 2x ukuran.
///
/// Dipakai di semua screen KECUALI WelcomeScreen.
/// Layout:
///   ┌─────────────────────────────────────────┐
///   │         [LOGO]  FAKULTAS KOPI           │
///   │                 PHOTObooth              │
///   └─────────────────────────────────────────┘
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({super.key, this.trailing});

  /// Widget opsional di kanan (misal: timer chip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      // Transparan — tanpa background putih
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center: logo + brand name
          _BrandLockup(),
          // Right: trailing widget (timer, etc.)
          if (trailing != null)
            Positioned(right: 0, child: trailing!),
        ],
      ),
    );
  }
}

/// Brand lockup center — logo + FAKULTAS KOPI + PHOTObooth.
/// Dipakai di header internal (2x ukuran dari sebelumnya).
class _BrandLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo 2x lebih besar (88px vs 44px sebelumnya), transparan
        Image.asset(
          'assets/images/logo.png',
          width: 64.r,
          height: 64.r,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_cafe_rounded,
            color: AppColors.darkBrown,
            size: 64.r,
          ),
        ),
        SizedBox(width: 12.w),
        // Brand text 2x
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FAKULTAS KOPI',
              style: AppTextStyles.brandNameLarge.copyWith(fontSize: 24.sp),
            ),
            Text(
              'PHOTObooth',
              style: AppTextStyles.brandSubtitle.copyWith(fontSize: 11.sp),
            ),
          ],
        ),
      ],
    );
  }
}

/// Timer chip untuk dipakai sebagai `trailing` di CustomerHeader.
class TimerChip extends StatelessWidget {
  const TimerChip({super.key, required this.text, this.isWarning = false});

  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.error : AppColors.darkBrown;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14.sp, color: color),
          SizedBox(width: 5.w),
          Text(
            text,
            style: AppTextStyles.timerText.copyWith(color: color, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
