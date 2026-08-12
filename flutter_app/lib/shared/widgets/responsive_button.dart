import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Primary action button — vintage pill style.
///
/// Primary:  dark brown fill + cream text (--button-brown #4A2915)
/// Outlined: transparent fill + dark brown border + dark text
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
        ? (isDisabled ? AppColors.lightBrown.withValues(alpha: 0.4) : AppColors.buttonBrown)
        : Colors.transparent;

    final borderColor = isPrimary
        ? Colors.transparent
        : (isDisabled
            ? AppColors.borderLight
            : AppColors.darkBrown);

    final textColor = isPrimary
        ? AppColors.creamWhite
        : (isDisabled ? AppColors.textMuted : AppColors.darkBrown);

    return SizedBox(
      width: width,
      height: h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isPrimary && !isDisabled
                  ? [
                      BoxShadow(
                        color: AppColors.darkBrown.withValues(alpha: 0.25),
                        blurRadius: 8,
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
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18.sp, color: textColor),
                          SizedBox(width: 8.w),
                        ],
                        Text(
                          label,
                          style: AppTextStyles.buttonText.copyWith(
                            color: textColor,
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
