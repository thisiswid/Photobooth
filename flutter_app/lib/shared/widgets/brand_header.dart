import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'logo_emblem.dart';

/// Header brand konsisten dipakai di semua screen (kecuali Welcome):
/// logo bulat + "FAKULTAS KOPI" + "PHOTOBOOTH", dengan chip timer
/// opsional di kanan saat sesi foto sedang berjalan.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.showTimer = false,
    this.timerText,
  });

  final bool showTimer;
  final String? timerText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
      child: Row(
        children: [
          LogoEmblem(size: 44.r, showRing: false),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FAKULTAS KOPI',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.coffeeBrown,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  Container(width: 14.w, height: 1, color: AppColors.goldAccent),
                  SizedBox(width: 6.w),
                  Text(
                    'PHOTOBOOTH',
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (showTimer) _TimerChip(text: timerText ?? '00:00'),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.coffeeBrown,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14.sp, color: AppColors.white),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
