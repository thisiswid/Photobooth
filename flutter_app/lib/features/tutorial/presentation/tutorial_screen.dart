import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Tutorial Screen — header transparan centered 2x, teks "Tutorial" di bawah header,
/// tombol LANJUT kecil di kanan bawah.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(number: '1', icon: Icons.qr_code_2_rounded,     title: 'BAYAR',       desc: 'Scan QRIS untuk membayar'),
    _TutorialStep(number: '2', icon: Icons.filter_frames_outlined, title: 'PILIH FRAME', desc: 'Pilih frame favoritmu'),
    _TutorialStep(number: '3', icon: Icons.camera_alt_outlined,    title: 'AMBIL FOTO',  desc: 'Berpose & ambil foto'),
    _TutorialStep(number: '4', icon: Icons.tune_rounded,           title: 'PILIH FILTER',desc: 'Pilih filter favoritmu'),
    _TutorialStep(number: '5', icon: Icons.download_rounded,       title: 'DOWNLOAD',    desc: 'Scan QR & cetak foto'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Column(
        children: [
          SizedBox(height: 8.h),

          // Judul "Tutorial"
          Text(
            'Tutorial',
            style: AppTextStyles.headlineLarge,
          ).animate().fadeIn(duration: 400.ms),

          SizedBox(height: 4.h),
          Text(
            'Ikuti langkah berikut untuk sesi fotomu',
            style: AppTextStyles.caption.copyWith(fontSize: 13.sp),
          ).animate().fadeIn(delay: 100.ms),
          SizedBox(height: 16.h),

          // Step cards
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _steps.asMap().entries.map((e) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: _StepCard(step: e.value, index: e.key)
                          .animate()
                          .fadeIn(delay: (e.key * 80).ms)
                          .slideY(begin: 0.06, delay: (e.key * 80).ms),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Tombol LANJUT — kecil di kanan bawah
          Padding(
            padding: EdgeInsets.only(right: 24.w, bottom: 16.h, top: 8.h),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 160.w,
                height: 44.h,
                child: ResponsiveButton(
                  label: 'LANJUT',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go(AppRoutes.payment),
                ),
              ).animate().fadeIn(delay: 500.ms),
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
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.darkBrown, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 8, offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26.r, height: 26.r,
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.darkBrown),
            child: Center(
              child: Text(step.number,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700,
                    color: AppColors.creamWhite)),
            ),
          ),
          SizedBox(height: 10.h),
          Icon(step.icon, color: AppColors.darkBrown, size: 26.sp),
          SizedBox(height: 8.h),
          Text(step.title,
            style: AppTextStyles.labelLarge.copyWith(
                letterSpacing: 0.5, color: AppColors.darkBrown),
            textAlign: TextAlign.center),
          SizedBox(height: 4.h),
          Text(step.desc,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.brown),
            textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({required this.number, required this.icon,
      required this.title, required this.desc});
  final String number;
  final IconData icon;
  final String title;
  final String desc;
}
