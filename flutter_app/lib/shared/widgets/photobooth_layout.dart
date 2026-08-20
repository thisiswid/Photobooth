import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'customer_header.dart';
import 'corner_decorations.dart';
import 'responsive_layout_builder.dart';

/// Layout frame for internal customer screens with authentic vintage coffeehouse styling.
/// Adapts cleanly across Mobile, Tablet, and Desktop resolutions.
class PhotoboothLayout extends StatelessWidget {
  const PhotoboothLayout({
    super.key,
    required this.child,
    this.showTimer = false,
    this.timerText,
    this.showDecorations = true,
    this.header,
    this.currentStep,
  });

  final Widget child;
  final bool showTimer;
  final String? timerText;
  final bool showDecorations;
  final Widget? header;
  final int? currentStep;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // ── Background warm parchment ─────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFBF4E8),
                  AppColors.cream,
                  Color(0xFFEFE2CF),
                ],
              ),
            ),
          ),

          // ── Subtle paper texture overlay ──────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _PaperTexturePainter()),
          ),

          // ── Vintage Inner Double-Border Frame (Desktop & Tablet) ──────
          if (!isMobile)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ),
            ),

          // ── Botanical corner decorations ──────────────────────────────
          if (showDecorations && !isMobile)
            const CornerDecorations(opacity: 0.25),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                header ??
                    CustomerHeader(
                      currentStep: currentStep,
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

/// Subtle paper grain texture — vintage paper noise overlay.
class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.darkBrown.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;

    const spacing = 4.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final noise = ((x * 7 + y * 13) % 17) / 17.0;
        if (noise > 0.65) {
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
