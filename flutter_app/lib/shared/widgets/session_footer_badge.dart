import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Footer badge displayed at the bottom of camera and preview screens matching UI Customer.png.
/// Text: "1 sesi foto: 5 menit | Maksimal 2 kali retake per pose"
class SessionFooterBadge extends StatelessWidget {
  const SessionFooterBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '1 sesi foto: 5 menit',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.coffeeBrown,
            ),
          ),
          Text(
            'Maksimal 2 kali retake per pose',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
