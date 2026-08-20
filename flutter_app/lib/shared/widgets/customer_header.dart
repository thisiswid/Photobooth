import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'responsive_layout_builder.dart';

/// Reusable internal page header with adaptive responsive coffee branding,
/// step progress indicator for user clarity, and timer chip.
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({
    super.key,
    this.trailing,
    this.currentStep,
  });

  /// Widget opsional di kanan (misal: timer chip).
  final Widget? trailing;

  /// Indikator tahap (1: Bayar, 2: Frame, 3: Foto, 4: Filter, 5: Hasil)
  final int? currentStep;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Container(
      height: isMobile ? 54.h : 68.h,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.w : 24.w,
        vertical: 4.h,
      ),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sisi Kiri: Logo + Nama Brand
          _BrandLockup(isMobile: isMobile),

          // Tengah: Step Progress (jika aktif dan ruang cukup)
          if (currentStep != null && currentStep! >= 1 && currentStep! <= 5)
            _AdaptiveStepIndicator(currentStep: currentStep!, isMobile: isMobile)
          else
            const SizedBox.shrink(),

          // Sisi Kanan: Timer Chip / Trailing Widget
          if (trailing != null)
            trailing!
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Brand lockup — logo + FAKULTAS KOPI + PHOTOBOOTH with adaptive sizing.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.isMobile = false});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 2.r : 4.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.creamWhite,
            border: Border.all(color: AppColors.gold, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkBrown.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: isMobile ? 28.r : 38.r,
            height: isMobile ? 28.r : 38.r,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.local_cafe_rounded,
              color: AppColors.darkBrown,
              size: isMobile ? 24.r : 34.r,
            ),
          ),
        ),
        SizedBox(width: isMobile ? 6.w : 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FAKULTAS KOPI',
              style: AppTextStyles.brandNameLarge.copyWith(
                fontSize: isMobile ? 13.sp : 17.sp,
                letterSpacing: isMobile ? 0.8 : 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 6.w : 12.w,
                  height: 1,
                  color: AppColors.gold,
                ),
                SizedBox(width: 3.w),
                Text(
                  'PHOTOBOOTH',
                  style: AppTextStyles.brandSubtitle.copyWith(
                    fontSize: isMobile ? 7.sp : 8.5.sp,
                    letterSpacing: isMobile ? 1.2 : 2.2,
                    color: AppColors.brown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3.w),
                Container(
                  width: isMobile ? 6.w : 12.w,
                  height: 1,
                  color: AppColors.gold,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Adaptive Step Progress Indicator
class _AdaptiveStepIndicator extends StatelessWidget {
  const _AdaptiveStepIndicator({required this.currentStep, required this.isMobile});

  final int currentStep;
  final bool isMobile;

  static const _stepLabels = [
    'Bayar',
    'Frame',
    'Foto',
    'Filter',
    'Hasil',
  ];

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      // Compact Mobile Step Pill
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.creamWhite.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.gold, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Langkah $currentStep/5',
              style: GoogleFonts.montserrat(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.darkBrown,
              ),
            ),
            SizedBox(width: 4.w),
            Text(
              '• ${_stepLabels[currentStep - 1]}',
              style: GoogleFonts.montserrat(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.vintageRust,
              ),
            ),
          ],
        ),
      );
    }

    // Full Tablet & Desktop Breadcrumb
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.creamWhite.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_stepLabels.length, (index) {
          final stepNum = index + 1;
          final isCurrent = stepNum == currentStep;
          final isPast = stepNum < currentStep;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 14.sp,
                    color: isPast ? AppColors.gold : AppColors.borderLight,
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCurrent ? 8.w : 5.w,
                  vertical: 3.h,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.darkBrown
                      : isPast
                          ? AppColors.paper
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                  border: isCurrent
                      ? Border.all(color: AppColors.gold, width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$stepNum',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: isCurrent
                            ? AppColors.gold
                            : isPast
                                ? AppColors.darkBrown
                                : AppColors.textMuted,
                      ),
                    ),
                    if (isCurrent) ...[
                      SizedBox(width: 4.w),
                      Text(
                        _stepLabels[index],
                        style: GoogleFonts.montserrat(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.creamWhite,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Timer chip adaptif untuk CustomerHeader.
class TimerChip extends StatelessWidget {
  const TimerChip({super.key, required this.text, this.isWarning = false});

  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final color = isWarning ? AppColors.error : AppColors.darkBrown;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8.w : 14.w,
        vertical: isMobile ? 4.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.creamWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isWarning ? AppColors.error : AppColors.gold,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
            size: isMobile ? 13.sp : 15.sp,
            color: color,
          ),
          SizedBox(width: isMobile ? 4.w : 6.w),
          Text(
            text,
            style: AppTextStyles.timerText.copyWith(
              color: color,
              fontSize: isMobile ? 11.sp : 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
