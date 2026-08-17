import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reusable internal page header — TRANSPARAN, logo & brand di kiri, timer di kanan.
///
/// Layout:
///   ┌────────────────────────────────────────────────────────┐
///   │ [LOGO] FAKULTAS KOPI                      [TIMER 04:59]│
///   │        PHOTObooth                                      │
///   └────────────────────────────────────────────────────────┘
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({super.key, this.trailing});

  /// Widget opsional di kanan (misal: timer chip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 6.h),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sisi Kiri: Logo + Nama Brand (Fakultas Kopi Photobooth)
          _BrandLockup(),

          // Sisi Kanan: Timer Chip / Trailing Widget (Dijamin tidak akan tumpang tindih)
          if (trailing != null)
            trailing!
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Brand lockup — logo + FAKULTAS KOPI + PHOTObooth.
class _BrandLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 48.r,
          height: 48.r,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_cafe_rounded,
            color: AppColors.darkBrown,
            size: 44.r,
          ),
        ),
        SizedBox(width: 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FAKULTAS KOPI',
              style: AppTextStyles.brandNameLarge.copyWith(
                fontSize: 18.sp,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'PHOTOBOOTH',
              style: AppTextStyles.brandSubtitle.copyWith(
                fontSize: 9.5.sp,
                letterSpacing: 2.0,
                color: AppColors.brown.withValues(alpha: 0.8),
              ),
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
        color: isWarning
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.creamWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isWarning ? AppColors.error : AppColors.borderWarm,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            text,
            style: AppTextStyles.timerText.copyWith(
              color: color,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
