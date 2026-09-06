import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/booth_material.dart';
import '../../features/provisioning/providers/tenant_provider.dart';
import 'logo_emblem.dart';
import 'responsive_layout_builder.dart';

/// Kepala halaman: lambang tenant + "<Nama Kafe> Photobooth".
class CustomerHeader extends ConsumerWidget {
  const CustomerHeader({
    super.key,
    this.material = BoothMaterial.paper,
    this.isLeftAligned = false,
  });

  final BoothMaterial material;
  final bool isLeftAligned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final cafeName = ref.watch(tenantNotifierProvider).valueOrNull?.cafe.name ??
        AppConstants.defaultCafeBrandName;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLeftAligned ? 0 : AppGeometry.s8.w,
        vertical: (isMobile ? AppGeometry.s4 : AppGeometry.s8).h,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isLeftAligned ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          LogoEmblem(size: isMobile ? 26.r : 32.r, showRing: false),
          SizedBox(width: AppGeometry.s8.w),
          Flexible(
            child: Text(
              '$cafeName Photobooth',
              textAlign: isLeftAligned ? TextAlign.start : TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.display(
                fontSize: (isMobile ? 15 : 18).sp,
                fontWeight: FontWeight.w700,
                color: material.onSurface,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pil timer sesi — satu-satunya tempat radius pil dipakai di aplikasi ini.
///
/// Angkanya tabular, jadi lebarnya tidak bergeser tiap detik. Saat waktu
/// menipis, warnanya berubah DAN kata "SISA" berganti "HABIS" — warna tidak
/// pernah jadi satu-satunya penanda.
class TimerChip extends StatelessWidget {
  const TimerChip({
    super.key,
    required this.text,
    this.isWarning = false,
    this.material = BoothMaterial.paper,
  });

  final String text;
  final bool isWarning;
  final BoothMaterial material;

  @override
  Widget build(BuildContext context) {
    final fg = isWarning
        ? (material.isDark ? AppColors.inkOxideLit : AppColors.inkOxide)
        : material.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppGeometry.s12.w,
        vertical: AppGeometry.s4.h,
      ),
      decoration: BoxDecoration(
        color: material.raised,
        borderRadius: BorderRadius.circular(AppGeometry.radiusPill.r),
        border: Border.all(
          color: isWarning ? fg : material.rule,
          width: isWarning ? AppGeometry.ruleSelected : AppGeometry.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isWarning ? 'HABIS' : 'SISA',
            style: AppFonts.ui(
              color: material.onSurfaceFaint,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(width: AppGeometry.s8.w),
          Text(
            text,
            style: AppFonts.ui(
              color: fg,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
