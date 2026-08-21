import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Vintage coffee botanical corner decorations.
///
/// Style: coffee plant leaves + thin branches + coffee beans,
/// antique engraving / classic coffee packaging line-art.
/// NO flowers. NO roses. NO modern botanical.
class CornerDecorations extends StatelessWidget {
  const CornerDecorations({
    super.key,
    this.size = 120,
    this.color,
    this.opacity = 0.35,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = (color ?? AppColors.darkBrown).withValues(alpha: opacity);

    return IgnorePointer(
      child: Stack(
        children: [
          // Top-left
          Positioned(
            top: 0, left: 0,
            child: SizedBox(
              width: size, height: size,
              child: CustomPaint(painter: _CoffeeBotanicalPainter(color: c)),
            ),
          ),
          // Top-right (flip horizontal)
          Positioned(
            top: 0, right: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
              child: SizedBox(
                width: size, height: size,
                child: CustomPaint(painter: _CoffeeBotanicalPainter(color: c)),
              ),
            ),
          ),
          // Bottom-left (flip vertical)
          Positioned(
            bottom: 0, left: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(1.0, -1.0, 1.0),
              child: SizedBox(
                width: size, height: size,
                child: CustomPaint(painter: _CoffeeBotanicalPainter(color: c)),
              ),
            ),
          ),
          // Bottom-right (flip both)
          Positioned(
            bottom: 0, right: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, -1.0, 1.0),
              child: SizedBox(
                width: size, height: size,
                child: CustomPaint(painter: _CoffeeBotanicalPainter(color: c)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a single corner with coffee botanical motif:
///   - main curved branch from (0,0) diagonally
///   - elongated pointed coffee leaves on branches
///   - small oval coffee beans
///   - delicate ornamental lines (vintage engraving style)
class _CoffeeBotanicalPainter extends CustomPainter {
  const _CoffeeBotanicalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // ── Main branch — curves from corner outward ──────────────────────────
    final mainBranch = Path()
      ..moveTo(0, 0)
      ..cubicTo(w * 0.08, h * 0.35, w * 0.38, h * 0.10, w * 0.75, h * 0.72);
    canvas.drawPath(mainBranch, stroke);

    // ── Secondary branch from mid-main ────────────────────────────────────
    final branch2 = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..quadraticBezierTo(w * 0.40, h * 0.06, w * 0.62, h * 0.20);
    canvas.drawPath(branch2, stroke);

    // ── Tertiary small branch ─────────────────────────────────────────────
    final branch3 = Path()
      ..moveTo(w * 0.42, h * 0.38)
      ..quadraticBezierTo(w * 0.55, h * 0.28, w * 0.68, h * 0.38);
    canvas.drawPath(branch3, stroke);

    // ── Coffee leaves — elongated, pointed, angled ────────────────────────
    // Each leaf: origin, rotation angle, length, width
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.10, h * 0.28), 0.6, w * 0.14, w * 0.045);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.22, h * 0.18), -0.3, w * 0.13, w * 0.042);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.38, h * 0.10), -0.7, w * 0.12, w * 0.038);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.54, h * 0.18), -0.2, w * 0.11, w * 0.035);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.44, h * 0.35), 1.0, w * 0.13, w * 0.040);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.58, h * 0.35), 0.5, w * 0.10, w * 0.032);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.55, h * 0.52), 1.2, w * 0.12, w * 0.038);
    _drawCoffeeLeaf(canvas, stroke, fill,
        Offset(w * 0.66, h * 0.58), 1.4, w * 0.10, w * 0.032);

    // ── Coffee beans — small ovals ─────────────────────────────────────────
    _drawCoffeeBean(canvas, stroke, fill, Offset(w * 0.28, h * 0.08), 3.5, 2.2);
    _drawCoffeeBean(canvas, stroke, fill, Offset(w * 0.46, h * 0.06), 3.0, 2.0);
    _drawCoffeeBean(canvas, stroke, fill, Offset(w * 0.60, h * 0.12), 2.8, 1.8);
    _drawCoffeeBean(canvas, stroke, fill, Offset(w * 0.72, h * 0.46), 2.5, 1.6);

    // ── Ornamental dot row — vintage engraving style ──────────────────────
    _drawDotRow(canvas, fill, Offset(w * 0.03, h * 0.06), 4, 4.0);

    // ── Corner bracket lines — classic frame detail ───────────────────────
    _drawCornerBracket(canvas, stroke, w, h);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _drawCoffeeLeaf(
    Canvas canvas,
    Paint stroke,
    Paint fill,
    Offset origin,
    double angle,
    double length,
    double width,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);

    // Leaf shape — elongated ellipse with pointed tip
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(width * 0.6, -width * 0.7, length * 0.8, -width * 0.3, length, 0)
      ..cubicTo(length * 0.8, width * 0.3, width * 0.6, width * 0.7, 0, 0)
      ..close();

    // Fill with low opacity for vintage paper look
    final leafFill = Paint()
      ..color = stroke.color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leaf, leafFill);
    canvas.drawPath(leaf, stroke);

    // Midrib line
    canvas.drawLine(
      Offset.zero,
      Offset(length * 0.88, 0),
      stroke..strokeWidth = 0.7,
    );

    // 2 vein lines
    canvas.drawLine(
      Offset(length * 0.25, 0),
      Offset(length * 0.35, -width * 0.45),
      stroke..strokeWidth = 0.5,
    );
    canvas.drawLine(
      Offset(length * 0.5, 0),
      Offset(length * 0.62, -width * 0.45),
      stroke..strokeWidth = 0.5,
    );

    stroke.strokeWidth = 0.9;
    canvas.restore();
  }

  void _drawCoffeeBean(
    Canvas canvas,
    Paint stroke,
    Paint fill,
    Offset center,
    double rx,
    double ry,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Outer oval
    final beanFill = Paint()
      ..color = stroke.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), beanFill);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), stroke..strokeWidth = 0.6);

    // Center crease line (characteristic coffee bean groove)
    canvas.drawLine(Offset(0, -ry * 0.8), Offset(0, ry * 0.8), stroke..strokeWidth = 0.5);

    stroke.strokeWidth = 0.9;
    canvas.restore();
  }

  void _drawDotRow(Canvas canvas, Paint fill, Offset start, int count, double spacing) {
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(start.dx, start.dy + i * spacing),
        0.9,
        fill,
      );
    }
  }

  void _drawCornerBracket(Canvas canvas, Paint stroke, double w, double h) {
    // Small L-bracket near corner — vintage frame detail
    final bracket = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.square;

    // Horizontal line
    canvas.drawLine(Offset(2, 2), Offset(14, 2), bracket);
    // Vertical line
    canvas.drawLine(Offset(2, 2), Offset(2, 14), bracket);
    // Inner small dots
    canvas.drawCircle(const Offset(5, 5), 0.8, Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _CoffeeBotanicalPainter old) => old.color != color;
}
