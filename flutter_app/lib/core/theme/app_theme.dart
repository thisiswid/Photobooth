import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';
import 'app_geometry.dart';
import 'app_text_styles.dart';

/// Tema Sistem Kamar Gelap.
///
/// Nama lama getter-nya `dark`, padahal isinya `Brightness.light` — sekarang
/// namanya `paper`, sesuai materialnya. Terang memang bawaan aplikasi ini;
/// gelap hanya dipakai di layar tempat gambar jadi subjeknya, dan layar-layar
/// itu memasang warnanya sendiri.
///
/// Seluruh nilai di sini diturunkan dari token. Tidak ada satu pun warna,
/// ukuran huruf, atau radius yang diketik langsung.
final class AppTheme {
  const AppTheme._();

  static ThemeData get paper => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _colorScheme,
        textTheme: _textTheme,
        scaffoldBackgroundColor: AppColors.paper,
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

        // Kedalaman datang dari garis dan cerukan, bukan dari blur.
        splashColor: AppColors.ink.withValues(alpha: 0.06),
        highlightColor: AppColors.ink.withValues(alpha: 0.04),
        shadowColor: Colors.transparent,
      );

  // ── Skema warna ──────────────────────────────────────────────────────────

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.ink,
    onPrimary: AppColors.paperBright,
    primaryContainer: AppColors.paperDeep,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.spot,
    onSecondary: AppColors.paperBright,
    secondaryContainer: AppColors.paperDeep,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.ink70,
    onTertiary: AppColors.paperBright,
    error: AppColors.inkOxide,
    onError: AppColors.paperBright,
    surface: AppColors.paperBright,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.paperDeep,
    onSurfaceVariant: AppColors.ink70,
    outline: AppColors.ink40,
    outlineVariant: AppColors.ink15,
    shadow: Colors.transparent,
    scrim: AppColors.scrim,
    inverseSurface: AppColors.bench,
    onInverseSurface: AppColors.light,
    inversePrimary: AppColors.spotLit,
  );

  // ── Tema teks ────────────────────────────────────────────────────────────

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      );

  // ── App bar ──────────────────────────────────────────────────────────────

  static const AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: AppColors.paper,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.paper,
    ),
  );

  // ── Tombol utama ─────────────────────────────────────────────────────────
  //
  // Target sentuh 64 ditegakkan di sini, sekali, untuk semua tombol.

  static ButtonStyle get _base => ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppGeometry.touchTarget.w, AppGeometry.touchTarget.h),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppGeometry.s24.w,
            vertical: AppGeometry.s12.h,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      );

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: _base.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.ink15
                : AppColors.ink,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.ink40
                : AppColors.paperBright,
          ),
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: _base.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.paperBright),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? AppColors.ink40
                : AppColors.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled)
                  ? AppColors.ink15
                  : AppColors.ink,
              width: AppGeometry.hairline,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.buttonText.copyWith(color: AppColors.ink),
          ),
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: Size(AppGeometry.s48.w, AppGeometry.touchTarget.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppGeometry.s16.w,
            vertical: AppGeometry.s8.h,
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      );

  // ── Kartu ────────────────────────────────────────────────────────────────
  //
  // Nol bayangan. Satu-satunya bayangan di aplikasi ini milik strip foto,
  // dan itu dipasang di widget-nya sendiri karena strip memang sebuah benda.

  static CardThemeData get _cardTheme => CardThemeData(
        color: AppColors.paperBright,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          side: const BorderSide(
            color: AppColors.ink15,
            width: AppGeometry.hairline,
          ),
        ),
        margin: EdgeInsets.zero,
      );

  // ── Isian ────────────────────────────────────────────────────────────────

  static OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
        borderSide: BorderSide(color: c, width: w),
      );

  static InputDecorationTheme get _inputDecorationTheme =>
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paperBright,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppGeometry.s16.w,
          vertical: AppGeometry.s16.h,
        ),
        border: _border(AppColors.ink15, AppGeometry.hairline),
        enabledBorder: _border(AppColors.ink15, AppGeometry.hairline),
        focusedBorder: _border(AppColors.ink, AppGeometry.ruleSelected),
        errorBorder: _border(AppColors.inkOxide, AppGeometry.hairline),
        focusedErrorBorder: _border(AppColors.inkOxide, AppGeometry.ruleSelected),
        labelStyle: AppTextStyles.labelMedium,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink40),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.inkOxide),
      );

  // ── Lembar bawah & dialog ────────────────────────────────────────────────

  static BottomSheetThemeData get _bottomSheetTheme => BottomSheetThemeData(
        backgroundColor: AppColors.paperBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppGeometry.radiusCard.r),
          ),
        ),
        elevation: 0,
        modalBarrierColor: AppColors.scrim,
      );

  static DialogThemeData get _dialogTheme => DialogThemeData(
        backgroundColor: AppColors.paperBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          side: const BorderSide(
            color: AppColors.ink,
            width: AppGeometry.hairline,
          ),
        ),
        elevation: 0,
        titleTextStyle: AppTextStyles.headlineMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      );

  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.paperBright),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      );

  // ── Sisanya ──────────────────────────────────────────────────────────────

  static const ProgressIndicatorThemeData _progressIndicatorTheme =
      ProgressIndicatorThemeData(
    color: AppColors.ink,
    linearTrackColor: AppColors.ink15,
    circularTrackColor: AppColors.ink15,
  );

  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.ink15,
    thickness: AppGeometry.hairline,
    space: AppGeometry.hairline,
  );

  static const IconThemeData _iconTheme = IconThemeData(
    color: AppColors.ink,
    size: 22,
  );
}
