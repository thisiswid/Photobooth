import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Tutorial Screen — Panduan 5 Langkah Sesi Photobooth yang Responsif & Centered CTA.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(
      number: '01',
      title: 'Bayar QRIS',
      desc: 'Scan QRIS untuk mulai',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _TutorialStep(
      number: '02',
      title: 'Pilih Frame',
      desc: 'Pilih bingkai favorit',
      icon: Icons.filter_frames_rounded,
    ),
    _TutorialStep(
      number: '03',
      title: 'Pose & Jepret',
      desc: 'Pose saat countdown',
      icon: Icons.photo_camera_rounded,
    ),
    _TutorialStep(
      number: '04',
      title: 'Filter Estetik',
      desc: 'Pilih nuansa warna',
      icon: Icons.auto_awesome_rounded,
    ),
    _TutorialStep(
      number: '05',
      title: 'Cetak & Unduh',
      desc: 'Cetak fisik & QR link',
      icon: Icons.print_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;

    final primaryColor = tenantConfig?.cafe.theme.primaryColor ?? AppColors.gold;
    final sessionPrice = tenantConfig?.pricing.sessionPrice ?? 25000;
    final formattedPrice = 'Rp ${NumberFormat('#,###', 'id_ID').format(sessionPrice)}';

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.w : 28.w,
            vertical: isMobile ? 4.h : 8.h,
          ),
          child: Column(
            children: [
              // ── Header Title & Subtitle ──────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PANDUAN SESI PHOTOBOOTH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: isMobile ? 20.sp : 26.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.creamWhite,
                      letterSpacing: isMobile ? 1.5 : 2.5,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),

                  SizedBox(height: 3.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isMobile ? 20.w : 32.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '5 Langkah Mudah Mengabadikan Momen Spesialmu',
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 9.5.sp : 11.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.creamWhite.withValues(alpha: 0.85),
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: isMobile ? 20.w : 32.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.7),
                      ),
                    ],
                  ).animate().fadeIn(delay: 120.ms),
                ],
              ),

              SizedBox(height: isMobile ? 10.h : 14.h),

              // ── Step Cards (Responsif LayoutBuilder) ───────────────────────
              Expanded(
                child: (isMobile || isPortrait)
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _steps.asMap().entries.map((e) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: _StepTileMobile(
                                step: e.value,
                                accentColor: primaryColor,
                              )
                                  .animate()
                                  .fadeIn(delay: (e.key * 50).ms)
                                  .slideX(begin: 0.04, delay: (e.key * 50).ms),
                            );
                          }).toList(),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _steps.asMap().entries.map((e) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5.w),
                              child: _StepCardLandscape(
                                step: e.value,
                                accentColor: primaryColor,
                              )
                                  .animate()
                                  .fadeIn(delay: (e.key * 60).ms)
                                  .slideY(begin: 0.06, delay: (e.key * 60).ms),
                            ),
                          );
                        }).toList(),
                      ),
              ),

              SizedBox(height: isMobile ? 10.h : 14.h),

              // ── Centered Grand Action Button (Tombol Bayar di Tengah) ────
              Center(
                child: SizedBox(
                  width: isMobile ? (isPortrait ? 260.w : 220.w) : 360.w,
                  height: isMobile ? 48.h : 56.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.darkBrown,
                      elevation: 8,
                      shadowColor: primaryColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                        side: const BorderSide(color: Colors.white24, width: 1.5),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 18.w),
                    ),
                    onPressed: () => context.go(AppRoutes.payment),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: isMobile ? 18.r : 22.r,
                          color: AppColors.darkBrown,
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANJUT KE PEMBAYARAN',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 11.5.sp : 13.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkBrown,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Sesi Foto — $formattedPrice',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 9.sp : 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkBrown.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: isMobile ? 16.r : 20.r,
                          color: AppColors.darkBrown,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.025, 1.025), duration: 1200.ms)
                    .animate()
                    .fadeIn(delay: 350.ms)
                    .slideY(begin: 0.1, delay: 350.ms),
              ),

              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step Card (Landscape Desktop & Tablet) ────────────────────────────────────

class _StepCardLandscape extends StatelessWidget {
  const _StepCardLandscape({
    required this.step,
    required this.accentColor,
  });

  final _TutorialStep step;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step number badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: accentColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              'LANGKAH ${step.number}',
              style: GoogleFonts.montserrat(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          SizedBox(height: 10.h),

          // Circle Icon Emblem
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.2),
            ),
            child: Icon(
              step.icon,
              color: accentColor,
              size: 22.r,
            ),
          ),

          SizedBox(height: 10.h),

          // Title
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.creamWhite,
              letterSpacing: 0.3,
            ),
          ),

          SizedBox(height: 4.h),

          // Description
          Text(
            step.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.creamWhite.withValues(alpha: 0.75),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step Tile (Portrait / Mobile) ─────────────────────────────────────────────

class _StepTileMobile extends StatelessWidget {
  const _StepTileMobile({
    required this.step,
    required this.accentColor,
  });

  final _TutorialStep step;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Step number badge
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
              border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.0),
            ),
            child: Center(
              child: Icon(
                step.icon,
                color: accentColor,
                size: 16.r,
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // Title & desc
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${step.number}. ',
                      style: GoogleFonts.montserrat(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      step.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamWhite,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  step.desc,
                  style: GoogleFonts.montserrat(
                    fontSize: 9.5.sp,
                    color: AppColors.creamWhite.withValues(alpha: 0.75),
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

// ── Data Class ────────────────────────────────────────────────────────────────

class _TutorialStep {
  const _TutorialStep({
    required this.number,
    required this.title,
    required this.desc,
    required this.icon,
  });

  final String number;
  final String title;
  final String desc;
  final IconData icon;
}
