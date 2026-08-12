import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'customer_header.dart';
import 'corner_decorations.dart';

/// Kerangka layout untuk semua screen INTERNAL (bukan Welcome).
///
/// Menyediakan:
/// - Background parchment (warm cream #F3E6D0)
/// - Subtle paper texture overlay (CustomPainter noise)
/// - Botanical corner decorations
/// - CustomerHeader (logo kecil kiri + brand name)
/// - SafeArea + content
///
/// Welcome Screen TIDAK menggunakan widget ini.
class PhotoboothLayout extends StatelessWidget {
  const PhotoboothLayout({
    super.key,
    required this.child,
    this.showTimer = false,
    this.timerText,
    this.showDecorations = true,
    this.header,
  });

  final Widget child;
  final bool showTimer;
  final String? timerText;
  final bool showDecorations;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // ── Background warm cream ──────────────────────────────────────
          Container(color: AppColors.cream),

          // ── Subtle paper texture overlay ──────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _PaperTexturePainter()),
          ),

          // ── Botanical corner decorations ──────────────────────────────
          if (showDecorations) const CornerDecorations(),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                header ??
                    CustomerHeader(
                      trailing: showTimer && timerText != null
                          ? TimerChip(text: timerText!)
                          : null,
                    ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle paper grain texture — very light noise overlay.
class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.darkBrown.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Simple dot grid untuk paper texture effect
    const spacing = 4.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Pseudo-random noise based on position
        final noise = ((x * 7 + y * 13) % 17) / 17.0;
        if (noise > 0.6) {
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
