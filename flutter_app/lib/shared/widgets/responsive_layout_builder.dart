import 'package:flutter/material.dart';

/// Jenis perangkat berdasarkan lebar layar (breakpoints).
enum ScreenType {
  mobile,
  tablet,
  desktop;

  bool get isMobile => this == ScreenType.mobile;
  bool get isTablet => this == ScreenType.tablet;
  bool get isDesktop => this == ScreenType.desktop;
}

/// Ekstensi praktis pada BuildContext untuk mendeteksi tipe layar & orientasi.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  Orientation get orientation => MediaQuery.of(this).orientation;

  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;

  ScreenType get screenType {
    final width = screenWidth;
    if (width < 600) {
      return ScreenType.mobile;
    } else if (width < 1024) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  bool get isMobile => screenType == ScreenType.mobile;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;
}

/// Widget builder adaptif untuk memudahkan pembuatan tampilan berbeda
/// di Mobile, Tablet, Desktop, serta mode Portrait dan Landscape.
class ResponsiveLayoutBuilder extends StatelessWidget {
  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    ScreenType screenType,
    bool isPortrait,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = context.screenType;
        final isPortrait = context.isPortrait;
        return builder(context, screenType, isPortrait);
      },
    );
  }
}
