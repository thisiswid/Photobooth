import 'dart:async';
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/frame/domain/models/frame_model.dart';
import '../../features/session/domain/models/session_model.dart';

/// Builds the full storage URL for a frame asset path.
String _storageUrl(String relativePath) {
  if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
    return relativePath;
  }
  String clean = relativePath;
  if (clean.startsWith('/')) clean = clean.substring(1);
  if (clean.startsWith('storage/')) clean = clean.substring('storage/'.length);
  final storageBase = AppConstants.apiBaseUrlDev.replaceAll('/api', '/storage');
  return '$storageBase/$clean';
}

/// Slot bounding box with mapped pose index
class _ResolvedSlot {
  final Rect rect;
  final int poseIndex; // 0-based index of which captured photo belongs here

  const _ResolvedSlot({required this.rect, required this.poseIndex});
}

/// A flexible, auto-responsive Photo Strip widget that:
/// 1. Auto-detects natural dimensions & aspect ratio of ANY uploaded frame (189x567, 1200x1800, etc.).
/// 2. Supports Single Strips, Double Strips (6 slots from 3 poses, 8 slots from 4 poses), and Grids.
/// 3. Supports custom right-column pose order (e.g. Left 1,2,3 - Right 3,1,2).
/// 4. Ensures photos are always rendered with BoxFit.cover so they are never squished ("tidak gepeng").
/// 5. Overlays live camera stream in active pose slot(s) in real-time.
class PhotoStripWidget extends StatefulWidget {
  const PhotoStripWidget({
    super.key,
    required this.photos,
    this.frame,
    this.filterTint,
    this.colorFilter,
    this.activePoseIndex,
    this.liveCameraPreview,
  });

  final List<PhotoModel> photos;
  final FrameModel? frame;
  final Color? filterTint;
  final ColorFilter? colorFilter;
  final int? activePoseIndex;
  final Widget? liveCameraPreview;

  @override
  State<PhotoStripWidget> createState() => _PhotoStripWidgetState();
}

class _PhotoStripWidgetState extends State<PhotoStripWidget> {
  double? _frameAspectRatio;
  double _canvasW = 1200.0;
  double _canvasH = 1800.0;

  @override
  void initState() {
    super.initState();
    _loadFrameSize();
  }

  @override
  void didUpdateWidget(PhotoStripWidget old) {
    super.didUpdateWidget(old);
    if (old.frame?.assetUrl != widget.frame?.assetUrl) {
      _frameAspectRatio = null;
      _loadFrameSize();
    }
  }

  /// Resolve the natural width & height of the uploaded PNG frame
  Future<void> _loadFrameSize() async {
    final url = widget.frame?.assetUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _canvasW = 1200.0;
          _canvasH = 1800.0;
          _frameAspectRatio = 2 / 3;
        });
      }
      return;
    }

    final imageProvider = NetworkImage(_storageUrl(url));
    final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);

    final completer = Completer<Size>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ));
        }
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(const Size(1200, 1800));
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    final size = await completer.future;
    if (!mounted) return;

    setState(() {
      _canvasW = size.width;
      _canvasH = size.height;
      _frameAspectRatio = size.width / size.height;
    });
  }

  /// Calculates slot coordinates normalized to a [0.0 - 1.0] relative bounding box
  /// and attaches each slot to its mapped pose index.
  List<_ResolvedSlot> _resolveSlots() {
    final frame = widget.frame;
    final int poseCount = frame?.poseCount ?? 3;
    final int slotCount = frame?.slotCount ?? poseCount;
    final String layoutType = frame?.layoutType ?? 'single';

    // 1. If explicit slots are configured in database
      if (frame?.slots != null && frame!.slots!.isNotEmpty) {
        final dbSlots = frame.slots!;
        double maxRight = 0;
        double maxBottom = 0;
        for (final s in dbSlots) {
          if (s.x + s.w > maxRight) maxRight = s.x + s.w;
          if (s.y + s.h > maxBottom) maxBottom = s.y + s.h;
        }
        final bool isNormalized = maxRight <= 1.05 && maxBottom <= 1.05;

        // Gunakan dimensi asli frame PNG sebagai pembagi.
        // Kalau _frameAspectRatio masih null (async belum selesai), pakai maxRight/maxBottom
        // supaya tidak salah bagi — widget akan rebuild otomatis setelah _loadFrameSize selesai.
        final double refW = isNormalized
            ? 1.0
            : (_frameAspectRatio != null && _canvasW > 0
                ? _canvasW
                : (maxRight > 500 ? 1200.0 : maxRight));
        final double refH = isNormalized
            ? 1.0
            : (_frameAspectRatio != null && _canvasH > 0
                ? _canvasH
                : (maxBottom > 800 ? 1800.0 : maxBottom));

      return List.generate(dbSlots.length, (i) {
        final s = dbSlots[i];
        final pIndex = s.poseIndex ?? (i % poseCount);
        return _ResolvedSlot(
          rect: Rect.fromLTWH(
            (s.x / refW).clamp(0.0, 1.0),
            (s.y / refH).clamp(0.0, 1.0),
            (s.w / refW).clamp(0.0, 1.0),
            (s.h / refH).clamp(0.0, 1.0),
          ),
          poseIndex: pIndex,
        );
      });
    }

    // 2. Double Strip 6 Slots (2 Columns × 3 Rows from 3 Poses)
    if (layoutType == 'double_6' || (slotCount == 6 && poseCount <= 3)) {
      final rightOrder = frame?.rightColumnOrder ?? [2, 0, 1]; // Default: Pose 3, Pose 1, Pose 2
      final List<_ResolvedSlot> slots = [];

      const double colW = 0.42;
      const double slotH = 0.265;
      const double leftColX = 0.055;
      const double rightColX = 0.525;
      const double topPadding = 0.04;
      const double gapY = 0.035;

      // Left Column: Pose 1, 2, 3 (index 0, 1, 2)
      for (int r = 0; r < 3; r++) {
        final top = topPadding + (r * (slotH + gapY));
        slots.add(_ResolvedSlot(
          rect: const Rect.fromLTWH(leftColX, 0, colW, slotH).shift(Offset(0, top)),
          poseIndex: r,
        ));
      }

      // Right Column: Custom Right Order (e.g. 3, 1, 2 -> index 2, 0, 1)
      for (int r = 0; r < 3; r++) {
        final top = topPadding + (r * (slotH + gapY));
        final mappedPose = (r < rightOrder.length) ? rightOrder[r] : (r % poseCount);
        slots.add(_ResolvedSlot(
          rect: const Rect.fromLTWH(rightColX, 0, colW, slotH).shift(Offset(0, top)),
          poseIndex: mappedPose,
        ));
      }
      return slots;
    }

    // 3. Double Strip 8 Slots (2 Columns × 4 Rows from 4 Poses)
    if (layoutType == 'double_8' || (slotCount == 8 && poseCount <= 4)) {
      final rightOrder = frame?.rightColumnOrder ?? [3, 0, 1, 2]; // Default: Pose 4, 1, 2, 3
      final List<_ResolvedSlot> slots = [];

      const double colW = 0.42;
      const double slotH = 0.20;
      const double leftColX = 0.055;
      const double rightColX = 0.525;
      const double topPadding = 0.035;
      const double gapY = 0.025;

      // Left Column: Pose 1, 2, 3, 4 (index 0, 1, 2, 3)
      for (int r = 0; r < 4; r++) {
        final top = topPadding + (r * (slotH + gapY));
        slots.add(_ResolvedSlot(
          rect: const Rect.fromLTWH(leftColX, 0, colW, slotH).shift(Offset(0, top)),
          poseIndex: r,
        ));
      }

      // Right Column: Custom Right Order
      for (int r = 0; r < 4; r++) {
        final top = topPadding + (r * (slotH + gapY));
        final mappedPose = (r < rightOrder.length) ? rightOrder[r] : (r % poseCount);
        slots.add(_ResolvedSlot(
          rect: const Rect.fromLTWH(rightColX, 0, colW, slotH).shift(Offset(0, top)),
          poseIndex: mappedPose,
        ));
      }
      return slots;
    }

    // 4. Single Vertical Strip (1:3 or 2x6 inch):
    final canvasRatio = _canvasW / _canvasH;
    final isVerticalStrip = canvasRatio <= 0.45; // e.g. 1:3 ratio (189x567)

    if (isVerticalStrip) {
      const double photoRatio = 4.0 / 2.99; // ~1.338
      const double sideMargin = 0.055;
      const double slotWidthRel = 1.0 - (2 * sideMargin);
      double slotHeightRel = (slotWidthRel * canvasRatio) / photoRatio;

      final totalRequiredHeight = poseCount * slotHeightRel;
      if (totalRequiredHeight > 0.86) {
        slotHeightRel = 0.82 / poseCount;
      }

      const double topPadding = 0.025;
      final remainingY = 0.96 - topPadding - (poseCount * slotHeightRel);
      final gap = poseCount > 1 ? (remainingY / (poseCount - 0.5)).clamp(0.008, 0.035) : 0.02;

      final List<_ResolvedSlot> slots = [];
      for (int i = 0; i < poseCount; i++) {
        final top = topPadding + (i * (slotHeightRel + gap));
        slots.add(_ResolvedSlot(
          rect: Rect.fromLTWH(sideMargin, top, slotWidthRel, slotHeightRel),
          poseIndex: i,
        ));
      }
      return slots;
    }

    // 5. Standard 4R Card Single Column (2:3 ratio):
    if (poseCount <= 2) {
      return const [
        _ResolvedSlot(rect: Rect.fromLTWH(0.05, 0.045, 0.90, 0.42), poseIndex: 0),
        _ResolvedSlot(rect: Rect.fromLTWH(0.05, 0.510, 0.90, 0.42), poseIndex: 1),
      ];
    } else if (poseCount == 3) {
      return const [
        _ResolvedSlot(rect: Rect.fromLTWH(0.05, 0.033, 0.90, 0.263), poseIndex: 0),
        _ResolvedSlot(rect: Rect.fromLTWH(0.05, 0.318, 0.90, 0.263), poseIndex: 1),
        _ResolvedSlot(rect: Rect.fromLTWH(0.05, 0.603, 0.90, 0.263), poseIndex: 2),
      ];
    } else {
      return const [
        _ResolvedSlot(rect: Rect.fromLTWH(0.042, 0.028, 0.916, 0.204), poseIndex: 0),
        _ResolvedSlot(rect: Rect.fromLTWH(0.042, 0.248, 0.916, 0.204), poseIndex: 1),
        _ResolvedSlot(rect: Rect.fromLTWH(0.042, 0.468, 0.916, 0.204), poseIndex: 2),
        _ResolvedSlot(rect: Rect.fromLTWH(0.042, 0.688, 0.916, 0.204), poseIndex: 3),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    final resolvedSlots = _resolveSlots();

    final isDoubleCol = (frame?.layoutType == 'double_6' || frame?.layoutType == 'double_8' || (frame?.slotCount ?? 0) >= 6);
    final aspectRatio = _frameAspectRatio ?? (isDoubleCol ? 2 / 3 : (frame?.poseCount ?? 4) >= 4 ? 1 / 3 : 2 / 3);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: AppColors.borderWarm),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBrown.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(2, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5.r),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Layer 1: Background paper ──────────────────────────────
                  Container(color: AppColors.creamWhite),

                  // ── Layer 2: Photo Slots (Proporsional & Anti-Gepeng) ──────
                  ...List.generate(resolvedSlots.length, (i) {
                    final slot = resolvedSlots[i];
                    final mappedPoseIndex = slot.poseIndex;
                    final photo = mappedPoseIndex < widget.photos.length ? widget.photos[mappedPoseIndex] : null;

                    return Positioned(
                      left:   slot.rect.left * width,
                      top:    slot.rect.top * height,
                      width:  slot.rect.width * width,
                      height: slot.rect.height * height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: _buildPhotoItem(
                          photo,
                          widget.filterTint,
                          widget.colorFilter,
                          mappedPoseIndex,
                          mappedPoseIndex + 1,
                        ),
                      ),
                    );
                  }),

                  // ── Layer 3: Frame PNG Overlay on Top ───────────────────────
                  if (frame?.assetUrl != null && frame!.assetUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        _storageUrl(frame.assetUrl!),
                        fit: BoxFit.fill,
                        errorBuilder: (ctx, err, stack) {
                          debugPrint('PhotoStripWidget: Failed to load frame image ${_storageUrl(frame.assetUrl!)} - $err');
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.darkBrown, width: 2.r),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.darkBrown, width: 2.r),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoItem(
    PhotoModel? photo,
    Color? tint,
    ColorFilter? colorFilter,
    int mappedPoseIndex,
    int poseNumber,
  ) {
    // ── Active Pose Live Camera Stream ───────────────────────────────────────
    if ((photo == null || photo.fileUrl.isEmpty) &&
        widget.activePoseIndex != null &&
        mappedPoseIndex == widget.activePoseIndex &&
        widget.liveCameraPreview != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview
          widget.liveCameraPreview!,

          // Active focus border
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1.5.r),
            ),
          ),

          // Live pill indicator in top-right
          Positioned(
            top: 3.r,
            right: 3.r,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.red.shade700.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(3.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 3.5.r,
                    height: 3.5.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 6.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (photo == null || photo.fileUrl.isEmpty) {
      return Container(
        color: AppColors.paper,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                color: AppColors.brown.withValues(alpha: 0.4),
                size: 14.sp,
              ),
              SizedBox(height: 2.h),
              Text(
                'Pose $poseNumber',
                style: TextStyle(
                  color: AppColors.brown.withValues(alpha: 0.6),
                  fontSize: 7.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget imageWidget;
    if (photo.fileUrl.startsWith('http://') || photo.fileUrl.startsWith('https://')) {
      imageWidget = Image.network(
        photo.fileUrl,
        fit: BoxFit.cover, // Ensures photo is NEVER squished/stretched!
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _errorBox(),
      );
    } else if (photo.fileUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        photo.fileUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _errorBox(),
      );
    } else {
      imageWidget = Image.file(
        dart_io.File(photo.fileUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Foto Sony 24 MP tidak boleh di-decode penuh untuk sel strip kecil.
        cacheWidth: 720,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _errorBox(),
      );
    }

    if (colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: colorFilter,
        child: imageWidget,
      );
    } else if (tint != null) {
      imageWidget = Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          Container(color: tint),
        ],
      );
    }

    return imageWidget;
  }

  Widget _errorBox() => Container(
        color: AppColors.paper,
        child: Center(
          child: Icon(Icons.broken_image, color: AppColors.brown, size: 20.sp),
        ),
      );
}
