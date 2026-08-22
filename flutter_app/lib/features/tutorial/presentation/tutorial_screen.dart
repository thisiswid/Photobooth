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
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Tutorial Screen — Panduan 5 Langkah Sesi Photobooth dengan Kotak Persegi Kompak & Tombol Tengah.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    _TutorialStep(
      number: '1',
      title: 'Bayar QRIS',
      desc: 'Scan QRIS untuk mulai',
      icon: Icons.qr_code_scanner_rounded,
    ),
    _TutorialStep(
      number: '2',
      title: 'Pilih Frame',
      desc: 'Pilih bingkai favoritmu',
      icon: Icons.filter_frames_rounded,
    ),
    _TutorialStep(
      number: '3',
      title: 'Ambil Foto',
      desc: 'Pose saat hitung mundur',
      icon: Icons.photo_camera_rounded,
    ),
    _TutorialStep(
      number: '4',
      title: 'Pilih Filter',
      desc: 'Sentuhan warna estetik',
      icon: Icons.auto_awesome_rounded,
    ),
    _TutorialStep(
      number: '5',
      title: 'Cetak & Unduh',
      desc: 'Cetak fisik & download QR',
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
            horizontal: isMobile ? 16.w : 24.w,
            vertical: isMobile ? 4.h : 6.h,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Header Title ─────────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PANDUAN SESI PHOTOBOOTH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: isMobile ? 18.sp : 24.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBrown,
                      letterSpacing: 1.5,
                    ),
                  ).animate().fadeIn(duration: 250.ms),

                  SizedBox(height: 2.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '5 Langkah Mudah untuk Mengabadikan Momenmu',
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 9.sp : 11.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brown,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 24.w,
                        height: 1.2,
                        color: primaryColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),

              // ── Kotak Panduan Persegi Kompak (Square Box) ─────────────────
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 8.h : 12.h),
                child: (isMobile || isPortrait)
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: _steps.asMap().entries.map((e) {
                          return _StepBoxSquare(
                            step: e.value,
                            accentColor: primaryColor,
                            width: isMobile ? 140.w : 150.w,
                            height: isMobile ? 110.h : 120.h,
                          )
                              .animate()
                              .fadeIn(delay: (e.key * 40).ms)
                              .scale(begin: const Offset(0.92, 0.92), delay: (e.key * 40).ms);
                        }).toList(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _steps.asMap().entries.map((e) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: _StepBoxSquare(
                              step: e.value,
                              accentColor: primaryColor,
                              width: 140.w,
                              height: 145.h,
                            )
                                .animate()
                                .fadeIn(delay: (e.key * 50).ms)
                                .scale(begin: const Offset(0.92, 0.92), delay: (e.key * 50).ms),
                          );
                        }).toList(),
                      ),
              ),

              // ── Tombol Bayar di Tengah Layar (Centered CTA Button) ───────
              Center(
                child: SizedBox(
                  width: isMobile ? (isPortrait ? 260.w : 220.w) : 340.w,
                  height: isMobile ? 46.h : 54.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonBrown,
                      foregroundColor: AppColors.creamWhite,
                      elevation: 6,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                        side: BorderSide(
                          color: primaryColor.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
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
                          color: AppColors.creamWhite,
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANJUT KE PEMBAYARAN',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 11.sp : 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.creamWhite,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Sesi Foto — $formattedPrice',
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 8.5.sp : 9.5.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.creamWhite.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: isMobile ? 16.r : 18.r,
                          color: AppColors.creamWhite,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.02, 1.02), duration: 1300.ms)
                    .animate()
                    .fadeIn(delay: 300.ms),
              ),

              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Kotak Biasa Persegi (Compact Square Box) ──────────────────────────────────

class _StepBoxSquare extends StatelessWidget {
  const _StepBoxSquare({
    required this.step,
    required this.accentColor,
    required this.width,
    required this.height,
  });

  final _TutorialStep step;
  final Color accentColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lingkaran Icon & Angka Step
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.buttonBrown.withValues(alpha: 0.08),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  step.icon,
                  color: AppColors.darkBrown,
                  size: 20.r,
                ),
              ),
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: AppColors.buttonBrown,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    step.number,
                    style: TextStyle(
                      color: AppColors.creamWhite,
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Judul Langkah
          Text(
            step.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBrown,
            ),
          ),

          SizedBox(height: 3.h),

          // Deskripsi Singkat
          Text(
            step.desc,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.brown,
              height: 1.2,
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
