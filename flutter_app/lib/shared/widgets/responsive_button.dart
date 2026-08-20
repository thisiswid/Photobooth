import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Primary action button — vintage pill style with tactile feel.
///
/// Primary:  dark espresso fill + subtle gold rim + cream text
/// Outlined: parchment fill + dark brown border + dark espresso text
enum ButtonVariant { primary, outlined }

class ResponsiveButton extends StatelessWidget {
  const ResponsiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final double? width;
  final double? height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final h = height ?? 56.h;
    final isPrimary = variant == ButtonVariant.primary;
    final isDisabled = onPressed == null;

    final bgColor = isPrimary
        ? (isDisabled ? AppColors.brown.withValues(alpha: 0.45) : AppColors.buttonBrown)
        : (isDisabled ? AppColors.paper.withValues(alpha: 0.5) : AppColors.creamWhite);

    final borderColor = isPrimary
        ? (isDisabled ? Colors.transparent : AppColors.gold.withValues(alpha: 0.8))
        : (isDisabled ? AppColors.borderLight : AppColors.darkBrown);

    final textColor = isPrimary
        ? (isDisabled ? AppColors.creamWhite.withValues(alpha: 0.7) : AppColors.creamWhite)
        : (isDisabled ? AppColors.textMuted : AppColors.darkBrown);

    return SizedBox(
      width: width,
      height: h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(30.r),
          splashColor: isPrimary
              ? AppColors.gold.withValues(alpha: 0.3)
              : AppColors.darkBrown.withValues(alpha: 0.15),
          highlightColor: isPrimary
              ? AppColors.darkCoffee
              : AppColors.paper,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: borderColor, width: isPrimary ? 1.2 : 1.5),
              boxShadow: !isDisabled
                  ? [
                      BoxShadow(
                        color: AppColors.darkBrown.withValues(alpha: isPrimary ? 0.28 : 0.08),
                        blurRadius: isPrimary ? 8 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22.r,
                      height: 22.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: textColor,
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 17.sp, color: isPrimary && !isDisabled ? AppColors.gold : textColor),
                            SizedBox(width: 6.w),
                          ],
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: textColor,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
