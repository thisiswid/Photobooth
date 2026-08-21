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

/// Tutorial Screen — Panduan 5 Langkah Sesi Photobooth yang Didominasi Visual Premium & Centered CTA.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(
      number: '01',
      title: 'Bayar QRIS',
      desc: 'Scan QRIS untuk memulai sesi foto',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _TutorialStep(
      number: '02',
      title: 'Pilih Frame',
      desc: 'Pilih desain bingkai foto favoritmu',
      icon: Icons.filter_frames_rounded,
    ),
    _TutorialStep(
      number: '03',
      title: 'Pose & Jepret',
      desc: 'Bergaya sesuai hitung mundur kamera',
      icon: Icons.photo_camera_rounded,
    ),
    _TutorialStep(
      number: '04',
      title: 'Filter Estetik',
      desc: 'Beri sentuhan warna vintage & aesthetic',
      icon: Icons.auto_awesome_rounded,
    ),
    _TutorialStep(
      number: '05',
      title: 'Cetak & Unduh',
      desc: 'Dapatkan cetak fisik & QR galeri digital',
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
            horizontal: isMobile ? 16.w : 32.w,
            vertical: isMobile ? 8.h : 16.h,
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
                      fontSize: isMobile ? 22.sp : 32.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.creamWhite,
                      letterSpacing: isMobile ? 1.5 : 2.5,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1),

                  SizedBox(height: 4.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isMobile ? 24.w : 40.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '5 Langkah Mudah Mengabadikan Momen Spesialmu',
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 10.sp : 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.creamWhite.withValues(alpha: 0.85),
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: isMobile ? 24.w : 40.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.7),
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms),
                ],
              ),

              SizedBox(height: isMobile ? 14.h : 22.h),

              // ── Step Cards List (Center Grid / Row) ───────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: (isMobile || isPortrait)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _steps.asMap().entries.map((e) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _StepTileMobile(
                                  step: e.value,
                                  accentColor: primaryColor,
                                )
                                    .animate()
                                    .fadeIn(delay: (e.key * 70).ms)
                                    .slideX(begin: 0.05, delay: (e.key * 70).ms),
                              );
                            }).toList(),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _steps.asMap().entries.map((e) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                                  child: _StepCardLandscape(
                                    step: e.value,
                                    accentColor: primaryColor,
                                  )
                                      .animate()
                                      .fadeIn(delay: (e.key * 80).ms)
                                      .slideY(begin: 0.08, delay: (e.key * 80).ms),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ),

              SizedBox(height: isMobile ? 14.h : 20.h),

              // ── Centered Grand Action Button (Tombol Bayar di Tengah) ────
              Center(
                child: SizedBox(
                  width: isMobile ? (isPortrait ? 280.w : 240.w) : 380.w,
                  height: isMobile ? 52.h : 62.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.darkBrown,
                      elevation: 8,
                      shadowColor: primaryColor.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32.r),
                        side: const BorderSide(color: Colors.white24, width: 1.5),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                    ),
                    onPressed: () => context.go(AppRoutes.payment),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: isMobile ? 20.r : 26.r,
                          color: AppColors.darkBrown,
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANJUT KE PEMBAYARAN',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 12.sp : 14.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkBrown,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'Sesi Foto — $formattedPrice',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 9.5.sp : 10.5.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkBrown.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: isMobile ? 18.r : 22.r,
                          color: AppColors.darkBrown,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.03, 1.03), duration: 1200.ms)
                    .animate()
                    .fadeIn(delay: 450.ms)
                    .slideY(begin: 0.15, delay: 450.ms),
              ),

              SizedBox(height: 6.h),
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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step number badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: accentColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              'LANGKAH ${step.number}',
              style: GoogleFonts.montserrat(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 1.0,
              ),
            ),
          ),

          SizedBox(height: 14.h),

          // Circle Icon Emblem
          Container(
            width: 52.r,
            height: 52.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Icon(
              step.icon,
              color: accentColor,
              size: 26.r,
            ),
          ),

          SizedBox(height: 14.h),

          // Title
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.creamWhite,
              letterSpacing: 0.5,
            ),
          ),

          SizedBox(height: 6.h),

          // Description
          Text(
            step.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.creamWhite.withValues(alpha: 0.75),
              height: 1.3,
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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Step number badge
          Container(
            width: 38.r,
            height: 38.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
              border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Center(
              child: Icon(
                step.icon,
                color: accentColor,
                size: 20.r,
              ),
            ),
          ),

          SizedBox(width: 14.w),

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
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      step.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 12.5.sp,
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
                    fontSize: 10.5.sp,
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
