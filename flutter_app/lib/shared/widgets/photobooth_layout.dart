import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../features/session/providers/session_provider.dart';
import 'customer_header.dart';
import 'corner_decorations.dart';
import 'responsive_layout_builder.dart';

/// Layout frame for internal customer screens with authentic vintage coffeehouse styling.
/// Session timer is always shown at screen top-right as a Positioned overlay — never inside the header.
class PhotoboothLayout extends ConsumerWidget {
  const PhotoboothLayout({
    super.key,
    required this.child,
    this.showTimer = false,   // kept for API compat — timer is auto-shown from session state
    this.timerText,           // kept for API compat — ignored
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final sessionState = ref.watch(sessionNotifierProvider);
    final hasTimer = sessionState.hasActiveSession || sessionState.remainingSeconds > 0;

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
                header ?? CustomerHeader(currentStep: currentStep),
                Expanded(child: child),
              ],
            ),
          ),

          // ── Session Timer — pojok kanan atas layar ────────────────────
          // Di luar SafeArea Column agar tidak bertabrakan dengan header
          if (hasTimer)
            Positioned(
              top: isMobile ? 12.h : 16.h,
              right: isMobile ? 12.w : 20.w,
              child: SafeArea(
                child: TimerChip(
                  text: sessionState.formattedRemainingTime,
                  isWarning: sessionState.isTimerWarning,
                  isMobile: isMobile,
                ),
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
