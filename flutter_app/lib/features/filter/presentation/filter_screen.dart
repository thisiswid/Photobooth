import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

class _Filter {
  const _Filter({required this.id, required this.name, required this.tint});
  final String id;
  final String name;
  final Color? tint;
}

const _filters = [
  _Filter(id: 'original', name: 'Original', tint: null),
  _Filter(id: 'vintage',  name: 'Vintage',  tint: Color(0x44704214)),
  _Filter(id: 'warm',     name: 'Warm',     tint: Color(0x33FF8C00)),
  _Filter(id: 'bw',       name: 'B&W',      tint: Color(0x99808080)),
  _Filter(id: 'classic',  name: 'Classic',  tint: Color(0x228B4513)),
];

/// Filter Screen — header transparan centered 2x.
class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  String _selectedId = _filters.first.id;

  void _onContinue() {
    ref.read(sessionNotifierProvider.notifier).setFilter(filterId: 1, filterName: _selectedId);
    context.go(AppRoutes.result);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(sessionNotifierProvider).remainingTime;
    final timerText = '${(remaining.inSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final photos = ref.watch(sessionNotifierProvider).session?.photos ?? [];
    final previewPhoto = photos.isNotEmpty ? photos.first : null;
    final selectedFilter = _filters.firstWhere((f) => f.id == _selectedId);

    return PhotoboothLayout(
      header: CustomerHeader(
        trailing: TimerChip(text: timerText, isWarning: remaining.inSeconds < 60),
      ),
      child: Row(
        children: [
          // ── Preview ────────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: AppTextStyles.titleMedium).animate().fadeIn(),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: AppColors.paper,
                            child: previewPhoto != null
                                ? Image.asset(previewPhoto.fileUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(Icons.photo, size: 64.sp, color: AppColors.lightBrown)))
                                : Center(child: Icon(Icons.photo, size: 64.sp, color: AppColors.lightBrown)),
                          ),
                          if (selectedFilter.tint != null) Container(color: selectedFilter.tint),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text('Filter: ${selectedFilter.name}', style: AppTextStyles.labelMedium),
                ],
              ),
            ),
          ),

          // ── Filter list ─────────────────────────────────────────────────
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
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (_, i) => _FilterTile(
                        filter: _filters[i],
                        isSelected: _filters[i].id == _selectedId,
                        onTap: () => setState(() => _selectedId = _filters[i].id),
                      ).animate().fadeIn(delay: (i * 60).ms),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ResponsiveButton(label: 'LANJUT', icon: Icons.arrow_forward_rounded,
                      onPressed: _onContinue, width: double.infinity, height: 52.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({required this.filter, required this.isSelected, required this.onTap});
  final _Filter filter;
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
            Container(width: 22.r, height: 22.r,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: filter.tint ?? AppColors.paper,
                border: Border.all(color: AppColors.borderWarm))),
            SizedBox(width: 10.w),
            Text(filter.name, style: AppTextStyles.titleSmall.copyWith(
              color: isSelected ? AppColors.creamWhite : AppColors.darkBrown,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_rounded, color: AppColors.creamWhite, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
