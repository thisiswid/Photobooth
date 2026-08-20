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

/// Tutorial Screen — Panduan 5 Langkah Sesi Photobooth bergaya Vintage Postage Stamp.
/// Responsif penuh untuk Desktop, Tablet, dan Smartphone.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(
      number: '1',
      icon: Icons.qr_code_2_rounded,
      title: 'BAYAR',
      subtitle: 'Scan QRIS',
      desc: 'Scan kode QRIS menggunakan e-wallet favoritmu.',
    ),
    _TutorialStep(
      number: '2',
      icon: Icons.filter_frames_outlined,
      title: 'PILIH FRAME',
      subtitle: 'Desain Bingkai',
      desc: 'Pilih desain bingkai foto yang paling kamu suka.',
    ),
    _TutorialStep(
      number: '3',
      icon: Icons.photo_camera_rounded,
      title: 'AMBIL FOTO',
      subtitle: 'Berpose Seru',
      desc: 'Siapkan pose terbaikmu saat hitung mundur kamera.',
    ),
    _TutorialStep(
      number: '4',
      icon: Icons.auto_fix_high_rounded,
      title: 'FILTER',
      subtitle: 'Efek Vintage',
      desc: 'Beri sentuhan warna film klasik pada fotomu.',
    ),
    _TutorialStep(
      number: '5',
      icon: Icons.print_rounded,
      title: 'CETAK & UNDUH',
      subtitle: 'Hasil Instan',
      desc: 'Foto otomatis dicetak dan scan QR untuk file HD & GIF.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Column(
        children: [
          SizedBox(height: isMobile ? 4.h : 6.h),

          // Header Judul & Subjudul Vintage
          Text(
            'Panduan Sesi Photobooth',
            style: GoogleFonts.cormorantGaramond(
              fontSize: isMobile ? 22.sp : 32.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBrown,
              letterSpacing: 0.5,
            ),
          ).animate().fadeIn(duration: 400.ms),

          SizedBox(height: 2.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: isMobile ? 12.w : 20.w, height: 1, color: AppColors.gold),
              SizedBox(width: 6.w),
              Text(
                'Ikuti 5 langkah mudah berikut untuk mengabadikan momenmu',
                style: AppTextStyles.caption.copyWith(
                  fontSize: isMobile ? 10.5.sp : 13.sp,
                  color: AppColors.brown,
                ),
              ),
              SizedBox(width: 6.w),
              Container(width: isMobile ? 12.w : 20.w, height: 1, color: AppColors.gold),
            ],
          ).animate().fadeIn(delay: 100.ms),

          SizedBox(height: isMobile ? 8.h : 14.h),

          // Step Cards (Adaptive for Mobile Portrait & Desktop Landscape)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.w : 20.w),
              child: isMobile || isPortrait
                  ? ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      itemCount: _steps.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, i) {
                        return _MobileStepTile(step: _steps[i], index: i)
                            .animate()
                            .fadeIn(delay: (i * 60).ms)
                            .slideY(begin: 0.05, delay: (i * 60).ms);
                      },
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _steps.asMap().entries.map((e) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                            child: _StepCard(step: e.value, index: e.key)
                                .animate()
                                .fadeIn(delay: (e.key * 90).ms)
                                .slideY(begin: 0.08, delay: (e.key * 90).ms),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          // Tombol Aksi di Bawah
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16.w : 24.w,
              6.h,
              isMobile ? 16.w : 24.w,
              isMobile ? 10.h : 14.h,
            ),
            child: isMobile
                ? SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ResponsiveButton(
                      label: 'LANJUT KE PEMBAYARAN',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => context.go(AppRoutes.payment),
                    ),
                  ).animate().fadeIn(delay: 400.ms)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Siap untuk berpose? Sentuh tombol di samping',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.brown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      SizedBox(
                        width: 220.w,
                        height: 50.h,
                        child: ResponsiveButton(
                          label: 'LANJUT KE PEMBAYARAN',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => context.go(AppRoutes.payment),
                        ),
                      ).animate().fadeIn(delay: 500.ms),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobileStepTile extends StatelessWidget {
  const _MobileStepTile({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Number Badge
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.buttonBrown,
              border: Border.all(color: AppColors.gold, width: 1.0),
            ),
            child: Center(
              child: Text(
                step.number,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.creamWhite,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Icon
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: AppColors.darkBrown, size: 20.sp),
          ),
          SizedBox(width: 10.w),

          // Texts
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
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '• ${step.subtitle}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.vintageRust,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  step.desc,
                  style: GoogleFonts.montserrat(
                    fontSize: 10.sp,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner Double Border for Vintage Stamp Look
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
            ),
          ),

          // Step Content
          Padding(
            padding: EdgeInsets.all(8.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Stamp Seal Number Badge
                Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.buttonBrown,
                    border: Border.all(color: AppColors.gold, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkBrown.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      step.number,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.creamWhite,
                      ),
                    ),
                  ),
                ),

                // Icon with Vintage Circle
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    color: AppColors.darkBrown,
                    size: 26.sp,
                  ),
                ),

                // Title
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.darkBrown,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      step.subtitle,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.vintageRust,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Description
                Text(
                  step.desc,
                  style: GoogleFonts.montserrat(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.brown,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
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
