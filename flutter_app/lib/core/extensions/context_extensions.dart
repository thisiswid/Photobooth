import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// Convenience extensions on [BuildContext] to reduce boilerplate.
extension BuildContextX on BuildContext {
  // ── Theme ─────────────────────────────────────────────────────────────────
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;

  // ── Brand Colors shorthand ────────────────────────────────────────────────
  Color get coffeeBrown => AppColors.coffeeBrown;
  Color get cream => AppColors.cream;
  Color get darkCoffee => AppColors.darkCoffee;
  Color get gold => AppColors.goldAccent;

  // ── Screen Dimensions ─────────────────────────────────────────────────────
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);
  double get statusBarHeight => MediaQuery.paddingOf(this).top;

  // ── Orientation ───────────────────────────────────────────────────────────
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
  bool get isPortrait =>
      MediaQuery.orientationOf(this) == Orientation.portrait;

  // ── Breakpoints ───────────────────────────────────────────────────────────
  bool get isSmallTablet => screenWidth < 800;
  bool get isMediumTablet => screenWidth >= 800 && screenWidth < 1200;
  bool get isLargeTablet => screenWidth >= 1200;

  // ── ScreenUtil Scaled Values ──────────────────────────────────────────────
  double sp(double size) => size.sp;
  double get w => 1.w;
  double get h => 1.h;

  // ── Snackbar helpers ──────────────────────────────────────────────────────
  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.errorLight : AppColors.coffeeBrown,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.r),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void showErrorSnack(String message) => showSnack(message, isError: true);

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(
        MaterialPageRoute(builder: (_) => page),
      );

  void pop<T>([T? result]) => Navigator.of(this).pop<T>(result);
}
