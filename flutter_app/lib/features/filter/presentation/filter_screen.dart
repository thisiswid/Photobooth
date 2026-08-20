import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../domain/models/filter_model.dart';
import '../providers/filter_provider.dart';

/// Builds the full storage URL for a relative asset path.
String _storageUrl(String relativePath) {
  final baseApi = AppConstants.apiBaseUrlDev;
  final storageBase = baseApi.replaceAll('/api', '/storage');
  return '$storageBase/$relativePath';
}

/// Filter Screen — Pemilihan Filter Film Vintage (Step 4).
class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  FilterModel? _selectedFilter;

  void _onContinue() {
    if (_selectedFilter == null) return;
    ref.read(sessionNotifierProvider.notifier).setFilter(
      filterId: _selectedFilter!.id,
      filterName: _selectedFilter!.name,
      filterModel: _selectedFilter,
    );
    context.go(AppRoutes.result);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final remaining = sessionState.remainingTime;
    final timerText = '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final photos = sessionState.session?.photos ?? [];
    final eventId = sessionState.session?.eventId ?? 1;
    final filtersAsync = ref.watch(filterListProvider(eventId));

    return PhotoboothLayout(
      currentStep: 4,
      header: CustomerHeader(
        currentStep: 4,
        trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
      ),
      child: filtersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.darkBrown)),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.brown),
              SizedBox(height: 12.h),
              Text('Gagal memuat filter', style: AppTextStyles.titleMedium),
              SizedBox(height: 8.h),
              Text(err.toString(), style: AppTextStyles.caption, textAlign: TextAlign.center),
              SizedBox(height: 16.h),
              ResponsiveButton(
                label: 'COBA LAGI',
                icon: Icons.refresh,
                onPressed: () {
                  ErrorLogger.instance.logRetryAttempt(
                    action: 'Muat Ulang Filter',
                    attempt: 1,
                    reason: err.toString(),
                  );
                  ref.invalidate(filterListProvider(eventId));
                },
                width: 200.w,
                height: 48.h,
              ),
            ],
          ),
        ),
        data: (filters) {
          // Auto-select first filter if none selected
          if (_selectedFilter == null && filters.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedFilter = filters.first);
            });
          }

          final isMobile = context.isMobile;
          final isPortrait = context.isPortrait;

          if (isMobile || isPortrait) {
            // ── Mobile / Portrait Layout ────────────────────────────────────
            return Padding(
              padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
              child: Column(
                children: [
                  Text('Pratinjau Hasil Foto', style: GoogleFonts.cormorantGaramond(fontSize: 22.sp, fontWeight: FontWeight.w800, color: AppColors.darkBrown)),
                  Text('Pilih filter film klasik favoritmu', style: AppTextStyles.caption.copyWith(fontSize: 10.5.sp)),
                  SizedBox(height: 6.h),

                  // Strip Preview di Tengah
                  Expanded(
                    child: Center(
                      child: PhotoStripWidget(
                        photos: photos,
                        frame: sessionState.selectedFrame,
                        colorFilter: _selectedFilter?.colorFilter,
                      ),
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Horizontal Filter Bar
                  SizedBox(
                    height: 52.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                      itemBuilder: (_, i) => _FilterTile(
                        filter: filters[i],
                        isSelected: _selectedFilter?.id == filters[i].id,
                        onTap: () => setState(() => _selectedFilter = filters[i]),
                      ).animate().fadeIn(delay: (i * 40).ms),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Tombol Lanjut
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ResponsiveButton(
                      label: 'LANJUT KE HASIL & CETAK',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _selectedFilter != null ? _onContinue : null,
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Desktop & Tablet Landscape Layout ───────────────────────────
          return Row(
            children: [
              // ── Preview Photo Strip with Frame & Filter (Flex: 3) ────────
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 4.h, 12.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Pratinjau Hasil Foto', style: AppTextStyles.headlineMedium)
                          .animate().fadeIn(),
                      SizedBox(height: 2.h),
                      Text('Sentuhan warna film klasik untuk sesi fotomu',
                          style: AppTextStyles.caption.copyWith(color: AppColors.brown)),
                      SizedBox(height: 8.h),
                      Expanded(
                        child: Center(
                          child: PhotoStripWidget(
                            photos: photos,
                            frame: sessionState.selectedFrame,
                            colorFilter: _selectedFilter?.colorFilter,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: AppColors.creamWhite,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.gold, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14.sp, color: AppColors.gold),
                            SizedBox(width: 6.w),
                            Text(
                              'Filter Aktif: ${_selectedFilter?.name ?? 'Normal'}',
                              style: GoogleFonts.montserrat(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Garis Pemisah Vertikal Vintage
              Container(
                width: 1.2.w,
                margin: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.gold.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // ── Filter list (Flex: 2) ──────────────────────────────
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 24.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pilih Efek Warna', style: AppTextStyles.headlineSmall)
                          .animate().fadeIn(),
                      SizedBox(height: 2.h),
                      Text('Pilih nuansa vintage yang paling pas', style: AppTextStyles.caption),
                      SizedBox(height: 12.h),

                      // Daftar Filter Vintage
                      Expanded(
                        child: ListView.separated(
                          itemCount: filters.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) => _FilterTile(
                            filter: filters[i],
                            isSelected: _selectedFilter?.id == filters[i].id,
                            onTap: () => setState(() => _selectedFilter = filters[i]),
                          ).animate().fadeIn(delay: (i * 50).ms),
                        ),
                      ),

                      SizedBox(height: 14.h),

                      ResponsiveButton(
                        label: 'LANJUT KE HASIL & CETAK',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _selectedFilter != null ? _onContinue : null,
                        width: double.infinity,
                        height: 52.h,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({required this.filter, required this.isSelected, required this.onTap});
  final FilterModel filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBrown : AppColors.creamWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.borderWarm,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.darkBrown.withValues(alpha: 0.04),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                width: 36.r,
                height: 36.r,
                child: filter.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _storageUrl(filter.thumbnailUrl!),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: filter.previewTint ?? AppColors.paper,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: filter.previewTint ?? AppColors.paper,
                          child: Icon(Icons.filter, size: 18.sp, color: AppColors.lightBrown),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: filter.previewTint ?? AppColors.paper,
                          border: Border.all(color: AppColors.borderWarm),
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          size: 18.sp,
                          color: isSelected ? AppColors.gold : AppColors.darkBrown,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                filter.name,
                style: GoogleFonts.montserrat(
                  fontSize: 13.sp,
                  color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(3.r),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 12.sp, color: AppColors.darkCoffee),
              ),
          ],
        ),
      ),
    );
  }
}
