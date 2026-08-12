import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Header dipakai khusus di layar sesi foto (Pilih Frame → Ambil Foto):
/// tombol kembali di kiri, judul aplikasi "KopiKlick" di tengah, dan
/// chip timer di kanan — sesuai referensi Detail_halaman_foto.png.
class SessionHeader extends StatelessWidget implements PreferredSizeWidget {
  const SessionHeader({
    super.key,
    required this.timerText,
    this.onBack,
  });

  final String timerText;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Row(
        children: [
          _BackButton(onTap: onBack ?? () => Navigator.of(context).maybePop()),
          Expanded(
            child: Column(
              children: [
                Text(
                  'KopiKlick',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.coffeeBrown,
                  ),
                ),
                Text(
                  'by Fakultas Kopi',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          _TimerChip(text: timerText),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(64.h);
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.parchmentLight,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, size: 16.sp, color: AppColors.coffeeBrown),
            SizedBox(width: 6.w),
            Text(
              'KEMBALI',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.coffeeBrown,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.parchmentLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 13.sp, color: AppColors.coffeeBrown),
          SizedBox(width: 5.w),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.coffeeBrown,
            ),
          ),
        ],
      ),
    );
  }
}
