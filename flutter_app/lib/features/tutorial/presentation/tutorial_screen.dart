import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Tutorial Screen — Panduan sesi photobooth, clean & minimal.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(number: '1', title: 'Bayar', desc: 'Scan QRIS untuk mulai sesi.'),
    _TutorialStep(number: '2', title: 'Pilih Frame', desc: 'Pilih bingkai favoritmu.'),
    _TutorialStep(number: '3', title: 'Ambil Foto', desc: 'Pose saat hitung mundur.'),
    _TutorialStep(number: '4', title: 'Filter', desc: 'Tambahkan sentuhan vintage.'),
    _TutorialStep(number: '5', title: 'Cetak & Unduh', desc: 'Cetak fisik & download QR.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16.w : 28.w,
          isMobile ? 0 : 4.h,
          isMobile ? 16.w : 28.w,
          isMobile ? 12.h : 16.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Judul — sedikit lebih ke atas ──────────────────────────────
            SizedBox(height: isMobile ? 4.h : 8.h),
            Text(
              'Panduan Sesi Photobooth',
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 20.sp : 26.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.darkBrown,
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(duration: 300.ms),

            SizedBox(height: isMobile ? 2.h : 4.h),

            // Divider tipis
            Container(
              width: 40.w,
              height: 1.2,
              color: AppColors.gold.withValues(alpha: 0.6),
            ).animate().fadeIn(delay: 100.ms),

            SizedBox(height: isMobile ? 12.h : 16.h),

            // ── Daftar langkah ─────────────────────────────────────────────
            Expanded(
              child: (isMobile || isPortrait)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: _steps.asMap().entries.map((e) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: isMobile ? 8.h : 10.h),
                          child: _StepRow(step: e.value, index: e.key)
                              .animate()
                              .fadeIn(delay: (e.key * 60).ms)
                              .slideY(begin: 0.04, delay: (e.key * 60).ms),
                        );
                      }).toList(),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _steps.asMap().entries.map((e) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: _StepCard(step: e.value, index: e.key)
                                .animate()
                                .fadeIn(delay: (e.key * 60).ms)
                                .slideY(begin: 0.04, delay: (e.key * 60).ms),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            // ── Tombol Lanjut — kanan bawah, kecil, tanpa icon ────────────
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () => context.go(AppRoutes.payment),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20.w : 28.w,
                    vertical: isMobile ? 9.h : 11.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.buttonBrown,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Lanjut',
                    style: GoogleFonts.montserrat(
                      fontSize: isMobile ? 12.sp : 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamWhite,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Row (portrait/mobile) ────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Number circle
        Container(
          width: isMobile ? 30.r : 36.r,
          height: isMobile ? 30.r : 36.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.buttonBrown.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              step.number,
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 13.sp : 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.darkBrown,
              ),
            ),
          ),
        ),

        SizedBox(width: isMobile ? 12.w : 16.w),

        // Title + desc
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step.title,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 12.sp : 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBrown,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                step.desc,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 10.sp : 11.sp,
                  color: AppColors.brown,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step Card (landscape) ─────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});
  final _TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32.r,
          height: 32.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.buttonBrown.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              step.number,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.darkBrown,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          step.title,
          style: GoogleFonts.montserrat(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBrown,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          step.desc,
          style: GoogleFonts.montserrat(
            fontSize: 10.5.sp,
            color: AppColors.brown,
          ),
        ),
      ],
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _TutorialStep {
  const _TutorialStep({
    required this.number,
    required this.title,
    required this.desc,
  });
  final String number;
  final String title;
  final String desc;
}
