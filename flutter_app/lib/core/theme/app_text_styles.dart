import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized text style definitions — Premium Vintage Coffee aesthetic.
///
/// Headings: Cormorant Garamond (elegant serif)
/// UI / Body: Montserrat (clean sans-serif)
/// Fallback:  Playfair Display (existing Google Font)
abstract final class AppTextStyles {
  // ── Display / Hero (Cormorant Garamond) ───────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.cormorantGaramond(
        fontSize: 72.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        letterSpacing: -1.0,
        height: 1.1,
      );

  static TextStyle get displayMedium => GoogleFonts.cormorantGaramond(
        fontSize: 56.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get displaySmall => GoogleFonts.cormorantGaramond(
        fontSize: 44.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        height: 1.2,
      );

  // ── Headlines (Cormorant Garamond) ────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.cormorantGaramond(
        fontSize: 36.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        height: 1.25,
      );

  static TextStyle get headlineMedium => GoogleFonts.cormorantGaramond(
        fontSize: 28.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        height: 1.3,
      );

  static TextStyle get headlineSmall => GoogleFonts.cormorantGaramond(
        fontSize: 22.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        height: 1.35,
      );

  // ── Brand Name (Cormorant Garamond — large welcome) ───────────────────────
  static TextStyle get brandNameLarge => GoogleFonts.cormorantGaramond(
        fontSize: 32.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        letterSpacing: 3.0,
        height: 1.1,
      );

  static TextStyle get brandSubtitle => GoogleFonts.montserrat(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.brown,
        letterSpacing: 4.0,
        height: 1.2,
      );

  // ── Header brand (internal pages, small left) ─────────────────────────────
  static TextStyle get headerBrandName => GoogleFonts.cormorantGaramond(
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        letterSpacing: 1.2,
        height: 1.1,
      );

  static TextStyle get headerBrandSub => GoogleFonts.montserrat(
        fontSize: 8.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.brown,
        letterSpacing: 3.0,
        height: 1.2,
      );

  // ── Titles (Montserrat) ───────────────────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.montserrat(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        height: 1.4,
      );

  static TextStyle get titleMedium => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        letterSpacing: 0.15,
        height: 1.4,
      );

  static TextStyle get titleSmall => GoogleFonts.montserrat(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.darkBrown,
        letterSpacing: 0.1,
        height: 1.4,
      );

  // ── Body (Montserrat) ─────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.montserrat(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.montserrat(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  // ── Labels ────────────────────────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.montserrat(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.montserrat(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      );

  static TextStyle get labelSmall => GoogleFonts.montserrat(
        fontSize: 10.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      );

  // ── Special Purpose ───────────────────────────────────────────────────────
  static TextStyle get buttonText => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.creamWhite,
        letterSpacing: 0.5,
      );

  static TextStyle get buttonTextLight => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.darkBrown,
        letterSpacing: 0.5,
      );

  static TextStyle get countdownNumber => GoogleFonts.cormorantGaramond(
        fontSize: 120.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        height: 1.0,
      );

  static TextStyle get timerText => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  static TextStyle get timerTextWarning => GoogleFonts.montserrat(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.error,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  static TextStyle get priceText => GoogleFonts.cormorantGaramond(
        fontSize: 36.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
      );

  static TextStyle get sessionCode => GoogleFonts.montserrat(
        fontSize: 20.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.darkBrown,
        letterSpacing: 4.0,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  static TextStyle get caption => GoogleFonts.cormorantGaramond(
        fontSize: 11.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        fontStyle: FontStyle.italic,
      );
}
