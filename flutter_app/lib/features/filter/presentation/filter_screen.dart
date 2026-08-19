import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
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
import '../domain/models/filter_model.dart';
import '../providers/filter_provider.dart';

/// Builds the full storage URL for a relative asset path.
String _storageUrl(String relativePath) {
  final baseApi = AppConstants.apiBaseUrlDev;
  final storageBase = baseApi.replaceAll('/api', '/storage');
  return '$storageBase/$relativePath';
}

/// Filter Screen — fetches filters from backend API.
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
      header: CustomerHeader(
        trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
      ),
      child: filtersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

          return Row(
            children: [
              // ── Preview Photo Strip with Frame & Filter ──────────
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Preview Photo Strip', style: AppTextStyles.titleMedium).animate().fadeIn(),
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
                      Text('Filter: ${_selectedFilter?.name ?? 'Normal'}',
                          style: AppTextStyles.labelMedium),
                    ],
                  ),
                ),
              ),

              // ── Filter list ────────────────────────────────────────
              Container(
                width: 200.w,
                decoration: BoxDecoration(border: Border(left: BorderSide(color: AppColors.borderWarm))),
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pilih Filter', style: AppTextStyles.headlineSmall).animate().fadeIn(),
                      SizedBox(height: 4.h),
                      Text('Sentuhan akhir fotomu', style: AppTextStyles.caption),
                      SizedBox(height: 16.h),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filters.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (_, i) => _FilterTile(
                            filter: filters[i],
                            isSelected: _selectedFilter?.id == filters[i].id,
                            onTap: () => setState(() => _selectedFilter = filters[i]),
                          ).animate().fadeIn(delay: (i * 60).ms),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ResponsiveButton(
                        label: 'LANJUT', icon: Icons.arrow_forward_rounded,
                        onPressed: _selectedFilter != null ? _onContinue : null,
                        width: double.infinity, height: 52.h,
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBrown : AppColors.creamWhite,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.darkBrown : AppColors.borderWarm,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: SizedBox(
                width: 32.r, height: 32.r,
                child: filter.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _storageUrl(filter.thumbnailUrl!),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: filter.previewTint ?? AppColors.paper,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: filter.previewTint ?? AppColors.paper,
                          child: Icon(Icons.filter, size: 16.sp, color: AppColors.lightBrown),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          color: filter.previewTint ?? AppColors.paper,
                          border: Border.all(color: AppColors.borderWarm),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(filter.name, style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ),
            if (isSelected) Icon(Icons.check_rounded, color: AppColors.creamWhite, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
