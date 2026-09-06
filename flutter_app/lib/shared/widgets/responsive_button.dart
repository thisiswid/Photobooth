import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/booth_material.dart';

/// Dua ragam tombol, dan tidak ada yang ketiga.
///
///   primary  — isian tinta penuh. Satu per layar.
///   outlined — permukaan polos + garis rambut tinta.
enum ButtonVariant { primary, outlined }

/// Tombol aksi Sistem Kamar Gelap.
///
/// Perubahan dari versi sebelumnya:
///   - radius 30 (pil) -> 4 (kartu). Pil hanya untuk timer sesi.
///   - bayangan dihapus. Kedalaman datang dari garis, bukan blur.
///   - rim emas dihapus.
///   - tinggi bawaan 56 -> 64, target sentuh minimum yang selama ini
///     dideklarasikan di AppConstants tapi tidak pernah ditegakkan.
///   - label jadi kapital condensed, seragam dari sini — bukan diketik
///     kapital satu per satu di tiap layar.
class ResponsiveButton extends StatelessWidget {
  const ResponsiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.material = BoothMaterial.paper,
    this.width,
    this.height,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final BoothMaterial material;
  final double? width;
  final double? height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == ButtonVariant.primary;
    final disabled = onPressed == null || isLoading;

    // Isian tinta di atas kertas; isian cahaya di atas meja gelap.
    final fill = material.isDark ? AppColors.light : AppColors.ink;
    final onFill = material.isDark ? AppColors.bench : AppColors.paperBright;

    final Color bg;
    final Color fg;
    final Color border;
    final double borderWidth;

    if (isPrimary) {
      bg = disabled ? material.rule : fill;
      fg = disabled ? material.onSurfaceFaint : onFill;
      border = bg;
      borderWidth = AppGeometry.hairline;
    } else {
      bg = material.raised;
      fg = disabled ? material.onSurfaceFaint : material.onSurface;
      border = disabled ? material.rule : material.ruleStrong;
      borderWidth = AppGeometry.hairline;
    }

    return SizedBox(
      width: width,
      height: height ?? AppGeometry.touchTarget.h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          // Ketukan berubah seketika — tanpa animasi, seperti mesin.
          splashFactory: NoSplash.splashFactory,
          highlightColor: fg.withValues(alpha: 0.10),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
              border: Border.all(color: border, width: borderWidth),
            ),
            padding: EdgeInsets.symmetric(horizontal: AppGeometry.s16.w),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18.sp, color: fg),
                          SizedBox(width: AppGeometry.s8.w),
                        ],
                        Flexible(
                          child: Text(
                            label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.ui(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
