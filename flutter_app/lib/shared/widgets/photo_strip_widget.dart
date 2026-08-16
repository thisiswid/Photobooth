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

/// A flexible, auto-responsive Photo Strip widget that:
/// 1. Auto-detects the natural dimensions & aspect ratio of ANY uploaded frame (189x567, 1200x1800, etc.).
/// 2. Dynamically calculates non-distorted photo slot coordinates (4cm x 2.99cm / 4:3 standard) for any pose count.
/// 3. Ensures photos are always rendered with BoxFit.cover so they are never squished ("tidak gepeng").
/// 4. Overlays the transparent PNG frame template on top.
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
  /// so that any container size and any canvas resolution scales with zero distortion.
  List<Rect> _resolveRelativeSlots(int poseCount) {
    // 1. If explicit slots are configured in database
    if (widget.frame?.slots != null && widget.frame!.slots!.isNotEmpty) {
      final dbSlots = widget.frame!.slots!;
      // Find reference canvas dimensions for the DB slots
      double maxRight = 0;
      double maxBottom = 0;
      for (final s in dbSlots) {
        if (s.x + s.w > maxRight) maxRight = s.x + s.w;
        if (s.y + s.h > maxBottom) maxBottom = s.y + s.h;
      }
      final refW = maxRight > 500 ? 1200.0 : _canvasW;
      final refH = maxBottom > 800 ? 1800.0 : _canvasH;

      return dbSlots.map((s) => Rect.fromLTWH(
        s.x / refW,
        s.y / refH,
        s.w / refW,
        s.h / refH,
      )).toList();
    }

    // 2. Dynamic Auto-Calculation for custom frames (e.g. 189x567 strip or any ratio)
    final canvasRatio = _canvasW / _canvasH;
    final isVerticalStrip = canvasRatio <= 0.45; // e.g. 1:3 ratio (189x567)

    if (isVerticalStrip) {
      // Photobooth Strip (1:3 or 2x6 inch):
      // Each photo is roughly 4cm wide x 2.99cm tall (~1.338:1 landscape aspect ratio)
      const double photoRatio = 4.0 / 2.99; // ~1.338
      const double sideMargin = 0.055; // 5.5% padding on left/right
      const double slotWidthRel = 1.0 - (2 * sideMargin); // 0.89 width
      
      // Calculate relative slot height in [0.0 - 1.0] coordinates
      // slotWidthInPx / slotHeightInPx = photoRatio
      // (slotWidthRel * _canvasW) / (slotHeightRel * _canvasH) = photoRatio
      // slotHeightRel = (slotWidthRel * _canvasW) / (_canvasH * photoRatio) = slotWidthRel * canvasRatio / photoRatio
      double slotHeightRel = (slotWidthRel * canvasRatio) / photoRatio;

      // Ensure all poses fit inside the vertical strip
      final totalRequiredHeight = poseCount * slotHeightRel;
      if (totalRequiredHeight > 0.86) {
        slotHeightRel = 0.82 / poseCount;
      }

      const double topPadding = 0.025; // 2.5% at top
      final remainingY = 0.96 - topPadding - (poseCount * slotHeightRel);
      final gap = poseCount > 1 ? (remainingY / (poseCount - 0.5)).clamp(0.008, 0.035) : 0.02;

      final List<Rect> slots = [];
      for (int i = 0; i < poseCount; i++) {
        final top = topPadding + (i * (slotHeightRel + gap));
        slots.add(Rect.fromLTWH(sideMargin, top, slotWidthRel, slotHeightRel));
      }
      return slots;
    } else {
      // Standard 4R Card (2:3 ratio, e.g. 1200x1800):
      if (poseCount <= 2) {
        return const [
          Rect.fromLTWH(0.05, 0.045, 0.90, 0.42),
          Rect.fromLTWH(0.05, 0.510, 0.90, 0.42),
        ];
      } else if (poseCount == 3) {
        return const [
          Rect.fromLTWH(0.05, 0.033, 0.90, 0.263),
          Rect.fromLTWH(0.05, 0.318, 0.90, 0.263),
          Rect.fromLTWH(0.05, 0.603, 0.90, 0.263),
        ];
      } else {
        return const [
          Rect.fromLTWH(0.042, 0.028, 0.916, 0.204),
          Rect.fromLTWH(0.042, 0.248, 0.916, 0.204),
          Rect.fromLTWH(0.042, 0.468, 0.916, 0.204),
          Rect.fromLTWH(0.042, 0.688, 0.916, 0.204),
        ];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    final poseCount = frame?.poseCount ?? (widget.photos.isNotEmpty ? widget.photos.length : 3);
    final relativeSlots = _resolveRelativeSlots(poseCount);

    // Dynamic aspect ratio: uses frame image ratio if resolved, else default 2:3 or 1:3
    final aspectRatio = _frameAspectRatio ?? (poseCount >= 4 ? 1 / 3 : 2 / 3);

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
                  ...List.generate(relativeSlots.length, (i) {
                    final slot = relativeSlots[i];
                    final photo = i < widget.photos.length ? widget.photos[i] : null;

                    return Positioned(
                      left:   slot.left * width,
                      top:    slot.top * height,
                      width:  slot.width * width,
                      height: slot.height * height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: _buildPhotoItem(
                          photo,
                          widget.filterTint,
                          widget.colorFilter,
                          i,
                          i + 1,
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
    int slotIndex,
    int poseNumber,
  ) {
    // ── Active Pose Live Camera Stream ───────────────────────────────────────
    if ((photo == null || photo.fileUrl.isEmpty) &&
        widget.activePoseIndex != null &&
        slotIndex == widget.activePoseIndex &&
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
                size: 16.sp,
              ),
              SizedBox(height: 2.h),
              Text(
                'Pose $poseNumber',
                style: TextStyle(
                  color: AppColors.brown.withValues(alpha: 0.6),
                  fontSize: 8.sp,
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
