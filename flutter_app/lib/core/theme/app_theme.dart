import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central theme configuration for SnapTechBooth.
/// Uses Material 3 with a custom coffee-themed color scheme.
final class AppTheme {
  const AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _colorScheme,
        textTheme: _textTheme,
        appBarTheme: _appBarTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        cardTheme: _cardTheme,
        inputDecorationTheme: _inputDecorationTheme,
        bottomSheetTheme: _bottomSheetTheme,
        dialogTheme: _dialogTheme,
        snackBarTheme: _snackBarTheme,
        progressIndicatorTheme: _progressIndicatorTheme,
        dividerTheme: _dividerTheme,
        iconTheme: _iconTheme,
        scaffoldBackgroundColor: AppColors.backgroundParchment,
        splashColor: AppColors.coffeeBrown.withValues(alpha: 0.1),
        highlightColor: AppColors.coffeeBrown.withValues(alpha: 0.05),
      );

  // ── Color Scheme ──────────────────────────────────────────────────────────
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.coffeeBrown,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.parchmentLight,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.goldAccent,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.parchmentDark,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.coffeeLight,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    surface: AppColors.surfaceCard,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.parchmentLight,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.borderWarm,
    outlineVariant: AppColors.borderGold,
    shadow: Colors.black26,
    scrim: Colors.black38,
    inverseSurface: AppColors.coffeeBrown,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.goldAccent,
  );

  // ── Text Theme ────────────────────────────────────────────────────────────
  static TextTheme get _textTheme => GoogleFonts.montserratTextTheme(
        TextTheme(
          displayLarge: GoogleFonts.cormorantGaramond(
            fontSize: 57.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          displayMedium: GoogleFonts.cormorantGaramond(
            fontSize: 45.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          displaySmall: GoogleFonts.cormorantGaramond(
            fontSize: 36.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineLarge: GoogleFonts.cormorantGaramond(
            fontSize: 32.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          headlineMedium: GoogleFonts.cormorantGaramond(
            fontSize: 28.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineSmall: GoogleFonts.cormorantGaramond(
            fontSize: 24.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleLarge: GoogleFonts.montserrat(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          titleMedium: GoogleFonts.montserrat(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleSmall: GoogleFonts.montserrat(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodyLarge: GoogleFonts.montserrat(
            fontSize: 16.sp,
            color: AppColors.textPrimary,
          ),
          bodyMedium: GoogleFonts.montserrat(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
          ),
          bodySmall: GoogleFonts.montserrat(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
          labelLarge: GoogleFonts.montserrat(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          labelMedium: GoogleFonts.montserrat(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          labelSmall: GoogleFonts.montserrat(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      );

  // ── App Bar ───────────────────────────────────────────────────────────────
  static const AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: AppColors.backgroundParchment,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundParchment,
    ),
  );

  // ── Elevated Button ───────────────────────────────────────────────────────
  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coffeeBrown,
          foregroundColor: AppColors.white,
          minimumSize: Size(120.w, 64.h),
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          elevation: 4,
          shadowColor: AppColors.coffeeBrown.withValues(alpha: 0.3),
        ),
      );

  // ── Outlined Button ───────────────────────────────────────────────────────
  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.coffeeBrown,
          side: const BorderSide(color: AppColors.coffeeBrown, width: 1.5),
          minimumSize: Size(120.w, 64.h),
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // ── Text Button ───────────────────────────────────────────────────────────
  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.coffeeBrown,
          minimumSize: Size(64.w, 48.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          textStyle: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  // ── Card ──────────────────────────────────────────────────────────────────
  static CardThemeData get _cardTheme => CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderWarm, width: 1),
        ),
        margin: EdgeInsets.all(8.r),
      );

  // ── Input Decoration ──────────────────────────────────────────────────────
  static InputDecorationTheme get _inputDecorationTheme =>
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.parchmentLight,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: AppColors.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
              const BorderSide(color: AppColors.borderWarm, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
              const BorderSide(color: AppColors.coffeeBrown, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
            fontSize: 14.sp, color: AppColors.textSecondary),
        hintStyle:
            GoogleFonts.inter(fontSize: 14.sp, color: AppColors.textMuted),
        errorStyle: GoogleFonts.inter(
            fontSize: 12.sp, color: AppColors.error),
      );

  // ── Bottom Sheet ──────────────────────────────────────────────────────────
  static BottomSheetThemeData get _bottomSheetTheme => BottomSheetThemeData(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        elevation: 16,
        modalBarrierColor: AppColors.overlayDark,
      );

  // ── Dialog ────────────────────────────────────────────────────────────────
  static DialogThemeData get _dialogTheme => DialogThemeData(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        elevation: 24,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 15.sp,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      );

  // ── SnackBar ──────────────────────────────────────────────────────────────
  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
        backgroundColor: AppColors.coffeeBrown,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      );

  // ── Progress Indicator ───────────────────────────────────────────────────
  static const ProgressIndicatorThemeData _progressIndicatorTheme =
      ProgressIndicatorThemeData(
    color: AppColors.coffeeBrown,
    linearTrackColor: AppColors.parchmentDark,
    circularTrackColor: AppColors.parchmentDark,
  );

  // ── Divider ───────────────────────────────────────────────────────────────
  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.borderWarm,
    thickness: 1,
    space: 1,
  );

  // ── Icon ──────────────────────────────────────────────────────────────────
  static const IconThemeData _iconTheme = IconThemeData(
    color: AppColors.coffeeBrown,
    size: 24,
  );
}
