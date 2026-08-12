import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Lambang "Fakultas Kopi": lingkaran tipis berisi logo dari assets/images/logo.png.
///
/// Pastikan sudah didaftarkan di pubspec.yaml:
/// ```yaml
/// flutter:
///   assets:
///     - assets/images/logo.png
/// ```
class LogoEmblem extends StatelessWidget {
  const LogoEmblem({
    super.key,
    this.size = 64,
    this.showRing = true,
    this.ringColor,
  });

  final double size;
  final bool showRing;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(size * 0.14),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.local_cafe_rounded,
          color: ringColor ?? AppColors.coffeeBrown,
          size: size * 0.5,
        ),
      ),
    );

    if (!showRing) return SizedBox(width: size, height: size, child: content);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: (ringColor ?? AppColors.goldAccent).withValues(alpha: 0.85),
          width: size * 0.02,
        ),
      ),
      child: content,
    );
  }
}
