import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import 'logo_emblem.dart';
import 'responsive_layout_builder.dart';

/// Reusable internal page header — logo + brand name centered only.
/// Session timer is rendered by PhotoboothLayout as a screen-level overlay.
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({
    super.key,
    this.trailing,        // kept for API compat — ignored, timer is in layout
    this.showTimer,       // kept for API compat — ignored
    this.currentStep,     // kept for API compat — ignored
  });

  final Widget? trailing;
  final bool? showTimer;
  final int? currentStep;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return SizedBox(
      height: isMobile ? 80.h : 96.h,
      child: Center(
        child: _BrandLockup(isMobile: isMobile),
      ),
    );
  }
}

/// Brand lockup — logo + "Nama Cafe Photobooth", centered.
class _BrandLockup extends ConsumerWidget {
  const _BrandLockup({this.isMobile = false});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName = tenantConfig?.cafe.name ?? AppConstants.defaultCafeBrandName;
    final title = '$cafeName Photobooth';

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LogoEmblem(
          size: isMobile ? 48.r : 60.r,
          showRing: false,
        ),
        SizedBox(height: 4.h),
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: isMobile ? 28.sp : 36.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBrown,
            letterSpacing: 0.4,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Session countdown chip — displayed at screen top-right by PhotoboothLayout.
class TimerChip extends StatelessWidget {
  const TimerChip({
    super.key,
    required this.text,
    this.isWarning = false,
    this.isMobile = false,
  });

  final String text;
  final bool isWarning;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.error : AppColors.darkBrown;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10.w : 14.w,
        vertical: isMobile ? 5.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.creamWhite,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isWarning
              ? AppColors.error
              : AppColors.darkBrown.withValues(alpha: 0.5),
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
            Icons.schedule_rounded,
            size: isMobile ? 13.sp : 15.sp,
            color: color,
          ),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: isMobile ? 12.sp : 13.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
