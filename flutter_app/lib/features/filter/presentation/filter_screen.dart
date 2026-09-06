import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../core/theme/booth_material.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
import '../../../shared/widgets/photobooth_layout.dart';
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

/// Filter Screen — Pemilihan Filter Film Kamar Gelap (Step 4).
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
    final photos = sessionState.session?.photos ?? [];
    final eventId = sessionState.session?.eventId ?? 1;
    final filtersAsync = ref.watch(filterListProvider(eventId));

    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final isCompact = isMobile || isPortrait;

    return PhotoboothLayout(
      material: BoothMaterial.paper,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient Background Watermarks (Crop marks, registration, studio watermark) ──
          _FilterBackground(isCompact: isCompact),

          // ── Content ────────────────────────────────────────────────────────
          filtersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.ink,
                strokeWidth: 2,
              ),
            ),
            error: (err, _) => Center(
              child: Container(
                margin: EdgeInsets.all(AppGeometry.s24.r),
                padding: EdgeInsets.all(AppGeometry.s24.r),
                decoration: BoxDecoration(
                  color: AppColors.paperBright,
                  border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 42.sp, color: AppColors.inkOxide),
                    SizedBox(height: AppGeometry.s12.h),
                    Text(
                      'GAGAL MEMUAT FILTER',
                      style: AppFonts.ui(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: AppGeometry.s8.h),
                    Text(
                      err.toString(),
                      style: AppFonts.display(
                        fontSize: 12.sp,
                        color: AppColors.ink70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppGeometry.s16.h),
                    ResponsiveButton(
                      label: 'Coba Lagi',
                      onPressed: () {
                        ErrorLogger.instance.logRetryAttempt(
                          action: 'Muat Ulang Filter',
                          attempt: 1,
                          reason: err.toString(),
                        );
                        ref.invalidate(filterListProvider(eventId));
                      },
                    ),
                  ],
                ),
              ),
            ),
            data: (filters) {
              // Auto-select first filter if none selected
              if (_selectedFilter == null && filters.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedFilter = filters.first);
                });
              }

              if (isCompact) {
                return _buildCompactLayout(context, filters, sessionState, photos);
              }

              return _buildLandscapeLayout(context, filters, sessionState, photos);
            },
          ),
        ],
      ),
    );
  }

  // ── Compact / Mobile / Portrait Layout ────────────────────────────────────

  Widget _buildCompactLayout(
    BuildContext context,
    List<FilterModel> filters,
    SessionState sessionState,
    List<dynamic> photos,
  ) {
    return Column(
      children: [
        // Sub-Header
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PILIH FILTER FILM',
                style: AppFonts.display(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.paperDeep,
                  border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                ),
                child: Text(
                  '${filters.length} OPSI',
                  style: AppFonts.ui(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(height: AppGeometry.hairline, color: AppColors.ink15),
        ),

        // Strip Preview di Tengah (Memaksimalkan Tinggi Strip)
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
              child: PhotoStripWidget(
                photos: sessionState.session?.photos ?? [],
                frame: sessionState.selectedFrame,
                colorFilter: _selectedFilter?.colorFilter,
              ),
            ),
          ),
        ),

        // Horizontal Swatch Bar (Lebih Ringkas & Kecil)
        Container(
          height: 48.h,
          color: AppColors.paperBright,
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => SizedBox(width: 6.w),
            itemBuilder: (_, i) => _CompactFilterChip(
              filter: filters[i],
              isSelected: _selectedFilter?.id == filters[i].id,
              onTap: () => setState(() => _selectedFilter = filters[i]),
            ).animate().fadeIn(delay: (i * 20).ms),
          ),
        ),

        // Bottom Action Bar (Sleek & Compact)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.paperBright,
            border: const Border(top: BorderSide(color: AppColors.ink15, width: AppGeometry.hairline)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedFilter?.name ?? 'Pilih Filter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.display(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Color Tone Applied',
                      style: AppFonts.ui(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spot,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              SizedBox(
                width: 140.w,
                child: ResponsiveButton(
                  label: 'Selanjutnya',
                  onPressed: _selectedFilter != null ? _onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Landscape / Desktop & Kiosk Layout ────────────────────────────────────

  // ── Landscape / Desktop & Kiosk Layout ────────────────────────────────────

  Widget _buildLandscapeLayout(
    BuildContext context,
    List<FilterModel> filters,
    SessionState sessionState,
    List<dynamic> photos,
  ) {
    return Row(
      children: [
        // ── Kiri (Flex: 5): Katalog Filter Swatch Card (Dibuat Lebih Compact & Kecil) ──
        Expanded(
          flex: 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PILIH FILTER FILM',
                      style: AppFonts.display(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.paperDeep,
                        border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                        borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
                      ),
                      child: Text(
                        '${filters.length} TONE',
                        style: AppFonts.ui(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),
                Container(height: AppGeometry.hairline, color: AppColors.ink15),
                SizedBox(height: 8.h),

                // Grid Swatch Kartu Filter: 4 kolom agar lebih compact dan muat banyak
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8.w,
                      mainAxisSpacing: 8.h,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filters.length,
                    itemBuilder: (_, i) {
                      final filter = filters[i];
                      final isSelected = _selectedFilter?.id == filter.id;
                      return _FilterCard(
                        filter: filter,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedFilter = filter),
                      ).animate().fadeIn(delay: (i * 20).ms);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Garis Pemisah Vertikal Hairline
        Container(
          width: AppGeometry.hairline,
          color: AppColors.ink15,
        ),

        // ── Kanan (Flex: 6): Live Print Preview (Dibuat Lebih Besar & Dominan) ──────
        Expanded(
          flex: 6,
          child: Container(
            color: AppColors.paperDeep,
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 20.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Frame Strip Preview Widget (Memaksimalkan Ukuran Strip)
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.paperBright,
                        border: Border.all(color: AppColors.ink15, width: AppGeometry.hairline),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.10),
                            blurRadius: AppGeometry.stripShadowBlur,
                            offset: const Offset(0, AppGeometry.stripShadowY),
                          ),
                        ],
                      ),
                      child: PhotoStripWidget(
                        photos: sessionState.session?.photos ?? [],
                        frame: sessionState.selectedFrame,
                        colorFilter: _selectedFilter?.colorFilter,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 14.h),

                // Tombol Selanjutnya
                ResponsiveButton(
                  label: 'Selanjutnya',
                  onPressed: _selectedFilter != null ? _onContinue : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Landscape Card Swatch Widget ─────────────────────────────────────────────

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final FilterModel filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tintColor = filter.previewTint ?? const Color(0xFFDCD2C3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.paperBright,
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.ink15,
            width: isSelected ? AppGeometry.ruleSelected : AppGeometry.hairline,
          ),
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.ink.withValues(alpha: 0.12)
                  : AppColors.ink.withValues(alpha: 0.03),
              blurRadius: isSelected ? 8 : 3,
              offset: isSelected ? const Offset(0, 3) : const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.spot : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Swatch Visual Block
              Expanded(
                child: Container(
                  color: AppColors.paperDeep,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail image bila ada, atau swatch palet warna filter
                      if (filter.thumbnailUrl != null && filter.thumbnailUrl!.isNotEmpty)
                        Image.network(
                          _storageUrl(filter.thumbnailUrl!),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(color: tintColor);
                          },
                          errorBuilder: (_, __, ___) => _DefaultSwatchDisplay(filter: filter, tint: tintColor),
                        )
                      else
                        _DefaultSwatchDisplay(filter: filter, tint: tintColor),

                      // Selected Badge (Stamp Style)
                      if (isSelected)
                        Positioned(
                          top: 4.r,
                          right: 4.r,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: AppColors.spot,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 8.sp, color: AppColors.paperBright),
                                SizedBox(width: 1.5.w),
                                Text(
                                  'PILIHAN',
                                  style: AppFonts.ui(
                                    fontSize: 7.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.paperBright,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Filter Name Banner (Dibuat Lebih Ramping & Kecil)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
                color: isSelected ? AppColors.ink : AppColors.paperBright,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter.name,
                      style: AppFonts.display(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.paperBright : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      filter.parameters?['type']?.toString().toUpperCase() ?? 'STANDARD',
                      style: AppFonts.ui(
                        fontSize: 7.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.paper : AppColors.ink70,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Default Swatch Display (Gradient & Palette Sample) ────────────────────────

class _DefaultSwatchDisplay extends StatelessWidget {
  const _DefaultSwatchDisplay({required this.filter, required this.tint});
  final FilterModel filter;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.85),
            tint.withValues(alpha: 0.45),
            AppColors.paperDeep,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.paperBright.withValues(alpha: 0.75),
            border: Border.all(color: AppColors.ink15, width: 0.8),
          ),
          child: Icon(
            Icons.palette_outlined,
            size: 20.sp,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

// ── Compact Filter Chip for Mobile ──────────────────────────────────────────

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final FilterModel filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = filter.previewTint ?? AppColors.paperDeep;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.paperBright,
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.ink15,
            width: isSelected ? AppGeometry.ruleSelected : AppGeometry.hairline,
          ),
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11.r,
              height: 11.r,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.paperBright : AppColors.ink15,
                  width: 0.8,
                ),
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              filter.name,
              style: AppFonts.ui(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.paperBright : AppColors.ink,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 4.w),
              Icon(Icons.check, size: 12.sp, color: AppColors.spotLit),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Background Studio Crop Marks & Watermarks ────────────────────────────────

class _FilterBackground extends StatelessWidget {
  const _FilterBackground({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 4 Sudut Crop Marks
          const _FilterCornerCropMarks(),

          // Cap Stempel Vintage Studio di latar belakang
          Positioned(
            top: isCompact ? 16.h : 28.h,
            right: isCompact ? 16.w : 38.w,
            child: const _FilterStampWatermark(),
          ),
        ],
      ),
    );
  }
}

class _FilterCornerCropMarks extends StatelessWidget {
  const _FilterCornerCropMarks();

  @override
  Widget build(BuildContext context) {
    const margin = 14.0;
    const len = 18.0;

    return const Stack(
      children: [
        Positioned(
          top: margin,
          left: margin,
          child: _CropCorner(isTop: true, isLeft: true, length: len),
        ),
        Positioned(
          top: margin,
          right: margin,
          child: _CropCorner(isTop: true, isLeft: false, length: len),
        ),
        Positioned(
          bottom: margin,
          left: margin,
          child: _CropCorner(isTop: false, isLeft: true, length: len),
        ),
        Positioned(
          bottom: margin,
          right: margin,
          child: _CropCorner(isTop: false, isLeft: false, length: len),
        ),
      ],
    );
  }
}

class _CropCorner extends StatelessWidget {
  const _CropCorner({
    required this.isTop,
    required this.isLeft,
    required this.length,
  });

  final bool isTop;
  final bool isLeft;
  final double length;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CropCornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _CropCornerPainter extends CustomPainter {
  _CropCornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink15
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterStampWatermark extends StatelessWidget {
  const _FilterStampWatermark();

  @override
  Widget build(BuildContext context) {
    final size = 95.r;
    return Transform.rotate(
      angle: 0.10,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.ink15,
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.ink15,
              width: 0.8,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '★ COLOR ★',
                  style: AppFonts.ui(
                    fontSize: 7.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink15,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'FILM TONE',
                  style: AppFonts.display(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink15,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'LAB GRADE',
                  style: AppFonts.ui(
                    fontSize: 7.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink15,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

