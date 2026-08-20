import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Tutorial Screen — Panduan 5 Langkah Sesi Photobooth.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(
      number: '1',
      icon: Icons.qr_code_2_rounded,
      title: 'BAYAR',
      subtitle: 'Scan QRIS',
      desc: 'Scan QRIS untuk mulai sesi.',
    ),
    _TutorialStep(
      number: '2',
      icon: Icons.filter_frames_outlined,
      title: 'PILIH FRAME',
      subtitle: 'Desain Bingkai',
      desc: 'Pilih bingkai favoritmu.',
    ),
    _TutorialStep(
      number: '3',
      icon: Icons.photo_camera_rounded,
      title: 'AMBIL FOTO',
      subtitle: 'Berpose Seru',
      desc: 'Pose saat hitung mundur.',
    ),
    _TutorialStep(
      number: '4',
      icon: Icons.auto_fix_high_rounded,
      title: 'FILTER',
      subtitle: 'Efek Film',
      desc: 'Sentuhan nuansa vintage.',
    ),
    _TutorialStep(
      number: '5',
      icon: Icons.print_rounded,
      title: 'CETAK & UNDUH',
      subtitle: 'Hasil Instan',
      desc: 'Cetak fisik & download QR.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12.w : 20.w,
          vertical: isMobile ? 4.h : 8.h,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Header Judul ────────────────────────────────────────────────
            Text(
              'Panduan Sesi Photobooth',
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 18.sp : 22.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.darkBrown,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(duration: 350.ms),

            SizedBox(height: 2.h),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14.w, height: 1, color: AppColors.gold.withValues(alpha: 0.6)),
                SizedBox(width: 6.w),
                Text(
                  '5 langkah mudah mengabadikan momen serumu',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: isMobile ? 9.sp : 10.sp,
                    color: AppColors.brown,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(width: 14.w, height: 1, color: AppColors.gold.withValues(alpha: 0.6)),
              ],
            ).animate().fadeIn(delay: 100.ms),

            SizedBox(height: isMobile ? 8.h : 10.h),

            // ── 5 Kartu Langkah ─────────────────────────────────────────────
            if (isMobile || isPortrait)
              // Portrait/Mobile: daftar vertikal
              Column(
                mainAxisSize: MainAxisSize.min,
                children: _steps.asMap().entries.map((e) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: _CompactMobileRow(step: e.value, index: e.key)
                        .animate()
                        .fadeIn(delay: (e.key * 50).ms)
                        .slideY(begin: 0.05, delay: (e.key * 50).ms),
                  );
                }).toList(),
              )
            else
              // Landscape: 5 kartu berjejer dengan tinggi tetap (tidak stretch)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _steps.asMap().entries.map((e) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: _CompactLandscapeCard(step: e.value, index: e.key)
                            .animate()
                            .fadeIn(delay: (e.key * 70).ms)
                            .slideY(begin: 0.06, delay: (e.key * 70).ms),
                      ),
                    );
                  }).toList(),
                ),
              ),

            SizedBox(height: isMobile ? 8.h : 14.h),

            // ── Tombol Aksi — selalu di tengah ──────────────────────────────
            Center(
              child: SizedBox(
                width: isMobile ? double.infinity : 280.w,
                height: isMobile ? 44.h : 48.h,
                child: ResponsiveButton(
                  label: 'LANJUT KE PEMBAYARAN',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go(AppRoutes.payment),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),

            SizedBox(height: isMobile ? 4.h : 6.h),
          ],
        ),
      ),
    );
  }
}

/// Kartu landscape compact — tinggi ditentukan oleh konten (IntrinsicHeight dari parent)
class _CompactLandscapeCard extends StatelessWidget {
  const _CompactLandscapeCard({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nomor badge
          Container(
            width: 24.r,
            height: 24.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.buttonBrown,
              border: Border.all(color: AppColors.gold, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                step.number,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.creamWhite,
                ),
              ),
            ),
          ),

          SizedBox(height: 6.h),

          // Ikon
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              color: AppColors.darkBrown,
              size: 18.sp,
            ),
          ),

          SizedBox(height: 6.h),

          // Judul
          Text(
            step.title,
            style: GoogleFonts.montserrat(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.darkBrown,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 2.h),

          // Subtitle italic
          Text(
            step.subtitle,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: AppColors.vintageRust,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 4.h),

          // Deskripsi singkat
          Text(
            step.desc,
            style: GoogleFonts.montserrat(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.brown,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Baris ringkas untuk mode Portrait / Mobile
class _CompactMobileRow extends StatelessWidget {
  const _CompactMobileRow({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Nomor badge
          Container(
            width: 22.r,
            height: 22.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.buttonBrown,
              border: Border.all(color: AppColors.gold, width: 1.0),
            ),
            child: Center(
              child: Text(
                step.number,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.creamWhite,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // Ikon
          Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: AppColors.darkBrown, size: 15.sp),
          ),
          SizedBox(width: 8.w),

          // Teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '• ${step.subtitle}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 10.sp,
                        fontStyle: FontStyle.italic,
                        color: AppColors.vintageRust,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  step.desc,
                  style: GoogleFonts.montserrat(
                    fontSize: 8.5.sp,
                    color: AppColors.brown,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.desc,
  });
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final String desc;
}
