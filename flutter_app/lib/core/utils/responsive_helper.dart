import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_constants.dart';

/// Screen size categories based on tablet width breakpoints.
enum ScreenSize { small, medium, large }

/// Responsive helper utilities for SnapTechBooth.
/// All sizing decisions should go through this class to ensure
/// consistent layout across 7–12" Android tablets.
abstract final class ResponsiveHelper {
  // ── Screen Size Classification ────────────────────────────────────────────

  /// Returns the [ScreenSize] category for the current [context].
  static ScreenSize screenSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.smallTabletBreakpoint) return ScreenSize.small;
    if (width < AppConstants.largeTabletBreakpoint) return ScreenSize.medium;
    return ScreenSize.large;
  }

  static bool isSmall(BuildContext context) =>
      screenSize(context) == ScreenSize.small;

  static bool isMedium(BuildContext context) =>
      screenSize(context) == ScreenSize.medium;

  static bool isLarge(BuildContext context) =>
      screenSize(context) == ScreenSize.large;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  // ── Responsive Value Selector ─────────────────────────────────────────────

  /// Returns [small], [medium], or [large] based on the current screen size.
  /// Falls back to the next available value if a specific size is not provided.
  static T value<T>(
    BuildContext context, {
    required T small,
    T? medium,
    T? large,
  }) {
    return switch (screenSize(context)) {
      ScreenSize.small => small,
      ScreenSize.medium => medium ?? small,
      ScreenSize.large => large ?? medium ?? small,
    };
  }

  // ── Scaled Dimensions ─────────────────────────────────────────────────────

  /// Font size scaled with ScreenUtil.
  static double sp(double size) => size.sp;

  /// Width as a fraction of screen width (0.0–1.0).
  static double wp(double fraction, BuildContext context) =>
      MediaQuery.sizeOf(context).width * fraction;

  /// Height as a fraction of screen height (0.0–1.0).
  static double hp(double fraction, BuildContext context) =>
      MediaQuery.sizeOf(context).height * fraction;

  /// Responsive padding based on screen size.
  static EdgeInsets screenPadding(BuildContext context) => value(
        context,
        small: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        medium: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        large: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
      );

  /// Responsive gap/spacing.
  static double gap(BuildContext context) => value(
        context,
        small: 12.w,
        medium: 16.w,
        large: 24.w,
      );

  // ── Grid Configuration ────────────────────────────────────────────────────

  /// Number of columns for a photo/card grid.
  static int gridColumns(BuildContext context, {int small = 2, int medium = 3, int large = 4}) =>
      value(context, small: small, medium: medium, large: large);

  // ── Button Sizing ─────────────────────────────────────────────────────────

  /// Minimum touch target height — always at least 64px per spec.
  static double buttonHeight(BuildContext context) => value(
        context,
        small: 64.h,
        medium: 72.h,
        large: 80.h,
      );

  /// Primary CTA button width.
  static double primaryButtonWidth(BuildContext context) => value(
        context,
        small: double.infinity,
        medium: 400.w,
        large: 480.w,
      );

  // ── Text Sizes ────────────────────────────────────────────────────────────

  /// Welcome screen hero title font size.
  static double heroTitleSize(BuildContext context) => value(
        context,
        small: 32.sp,
        medium: 48.sp,
        large: 64.sp,
      );

  /// Section heading font size.
  static double sectionTitleSize(BuildContext context) => value(
        context,
        small: 20.sp,
        medium: 26.sp,
        large: 32.sp,
      );

  /// Body text font size.
  static double bodyTextSize(BuildContext context) => value(
        context,
        small: 13.sp,
        medium: 15.sp,
        large: 16.sp,
      );

  // ── Camera Preview ────────────────────────────────────────────────────────

  /// Maximum height for camera preview container.
  static double cameraPreviewMaxHeight(BuildContext context) => value(
        context,
        small: MediaQuery.sizeOf(context).height * 0.65,
        medium: MediaQuery.sizeOf(context).height * 0.70,
        large: MediaQuery.sizeOf(context).height * 0.75,
      );

  // ── Card Sizing ───────────────────────────────────────────────────────────

  /// Package selection card width.
  static double packageCardWidth(BuildContext context) => value(
        context,
        small: 220.w,
        medium: 260.w,
        large: 300.w,
      );

  /// Layout option card width in the selection grid.
  static double layoutCardWidth(BuildContext context) => value(
        context,
        small: 140.w,
        medium: 170.w,
        large: 200.w,
      );
}
