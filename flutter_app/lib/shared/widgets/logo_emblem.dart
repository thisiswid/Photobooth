import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/provisioning/providers/tenant_provider.dart';

/// Lambang Brand Dinamis: menampilkan logo dari Tenant Cafe yang aktif,
/// atau logo SnapTech / default logo jika belum ter-provision.
class LogoEmblem extends ConsumerWidget {
  const LogoEmblem({
    super.key,
    this.size = 64,
    this.showRing = true,
    this.ringColor,
    this.customLogoUrl,
  });

  final double size;
  final bool showRing;
  final Color? ringColor;
  final String? customLogoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final logoUrl = customLogoUrl ?? tenantConfig?.cafe.logoUrl;

    Widget logoContent;

    if (logoUrl != null && logoUrl.isNotEmpty) {
      logoContent = CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => Center(
          child: SizedBox(
            width: size * 0.4,
            height: size * 0.4,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.goldAccent,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _buildFallbackImage(),
      );
    } else {
      logoContent = _buildFallbackImage();
    }

    final content = Padding(
      padding: EdgeInsets.all(size * 0.12),
      child: logoContent,
    );

    if (!showRing) return SizedBox(width: size, height: size, child: content);

    final themeRingColor = tenantConfig?.cafe.theme.primaryColor ?? (ringColor ?? AppColors.goldAccent);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: themeRingColor.withValues(alpha: 0.85),
          width: size * 0.025,
        ),
      ),
      child: content,
    );
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      AppConstants.logoSnaptechAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        AppConstants.defaultLogoAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.camera_alt_rounded,
          color: ringColor ?? AppColors.coffeeBrown,
          size: size * 0.5,
        ),
      ),
    );
  }
}
