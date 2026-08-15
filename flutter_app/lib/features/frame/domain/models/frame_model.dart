class FrameSlot {
  final double x;
  final double y;
  final double w;
  final double h;

  const FrameSlot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory FrameSlot.fromJson(Map<String, dynamic> json) {
    return FrameSlot(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 1100,
      h: (json['h'] as num?)?.toDouble() ?? 367,
    );
  }
}

class FrameModel {
  final int id;
  final String name;
  final String? assetUrl;
  final int poseCount;
  final List<FrameSlot>? slots;

  const FrameModel({
    required this.id,
    required this.name,
    this.assetUrl,
    this.poseCount = 4,
    this.slots,
  });

  factory FrameModel.fromJson(Map<String, dynamic> json) {
    List<FrameSlot>? parsedSlots;
    if (json['layout_config'] != null && json['layout_config'] is Map) {
      final config = json['layout_config'] as Map<String, dynamic>;
      if (config['slots'] != null && config['slots'] is List) {
        parsedSlots = (config['slots'] as List)
            .map((s) => FrameSlot.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    }

    return FrameModel(
      id: json['id'] as int,
      name: json['name'] as String,
      assetUrl: json['asset_url'] as String?,
      poseCount: json['pose_count'] as int? ?? (parsedSlots?.length ?? 4),
      slots: parsedSlots,
    );
  }

  /// Full URL for the frame asset image.
  String? get fullAssetUrl {
    if (assetUrl == null || assetUrl!.isEmpty) return null;
    return assetUrl;
  }
}
