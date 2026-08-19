class FrameSlot {
  final double x;
  final double y;
  final double w;
  final double h;
  final int? poseIndex; // 0-based mapped pose index (e.g. 0, 1, 2)

  const FrameSlot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.poseIndex,
  });

  factory FrameSlot.fromJson(Map<String, dynamic> json) {
    return FrameSlot(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 1100,
      h: (json['h'] as num?)?.toDouble() ?? 367,
      poseIndex: (json['pose_index'] as num?)?.toInt(),
    );
  }
}

class FrameModel {
  final int id;
  final String name;
  final String? assetUrl;
  final int poseCount;
  final int slotCount;
  final String layoutType; // 'single', 'double_6', 'double_8', 'grid_4', 'custom'
  final List<int>? rightColumnOrder; // e.g. [2, 0, 1] for 3, 1, 2
  final List<FrameSlot>? slots;
  final String? eventName;

  const FrameModel({
    required this.id,
    required this.name,
    this.assetUrl,
    this.poseCount = 4,
    this.slotCount = 4,
    this.layoutType = 'single',
    this.rightColumnOrder,
    this.slots,
    this.eventName,
  });

  factory FrameModel.fromJson(Map<String, dynamic> json) {
    List<FrameSlot>? parsedSlots;
    String layoutType = 'single';
    int slotCount = 4;
    List<int>? rightOrder;

    // 1. Read top-level fields first (new API format)
    if (json['layout_type'] != null) {
      layoutType = json['layout_type'] as String? ?? 'single';
    }
    if (json['slot_count'] != null) {
      slotCount = (json['slot_count'] as num?)?.toInt() ?? 4;
    }
    if (json['right_column_order'] != null && json['right_column_order'] is List) {
      rightOrder = (json['right_column_order'] as List)
          .map((e) => (e as num).toInt())
          .toList();
    }
    if (json['slots'] != null && json['slots'] is List) {
      parsedSlots = (json['slots'] as List)
          .map((s) => FrameSlot.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    // 2. Fallback: read from nested layout_config (backward compat)
    if (json['layout_config'] != null && json['layout_config'] is Map) {
      final config = json['layout_config'] as Map<String, dynamic>;
      // Only override if top-level was not set
      if (json['layout_type'] == null) {
        layoutType = config['layout_type'] as String? ?? layoutType;
      }
      if (json['slot_count'] == null) {
        slotCount = (config['slot_count'] as num?)?.toInt() ?? slotCount;
      }
      if (json['right_column_order'] == null && config['right_column_order'] is List) {
        rightOrder = (config['right_column_order'] as List)
            .map((e) => (e as num).toInt())
            .toList();
      }
      if (config['slots'] != null && config['slots'] is List) {
        parsedSlots = (config['slots'] as List)
            .map((s) => FrameSlot.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    }

    final int rawPoseCount = json['pose_count'] as int? ?? 4;

    // Determine actual slot count
    if (parsedSlots != null && parsedSlots.isNotEmpty) {
      slotCount = parsedSlots.length;
    } else if (layoutType == 'double_6') {
      slotCount = 6;
    } else if (layoutType == 'double_8') {
      slotCount = 8;
    } else {
      slotCount = rawPoseCount;
    }

    String? eventName;
    if (json['event'] != null && json['event'] is Map) {
      eventName = json['event']['name'] as String?;
    }

    return FrameModel(
      id: json['id'] as int,
      name: json['name'] as String,
      assetUrl: json['asset_url'] as String?,
      poseCount: rawPoseCount,
      slotCount: slotCount,
      layoutType: layoutType,
      rightColumnOrder: rightOrder,
      slots: parsedSlots,
      eventName: eventName,
    );
  }

  /// Full URL for the frame asset image.
  String? get fullAssetUrl {
    if (assetUrl == null || assetUrl!.isEmpty) return null;
    return assetUrl;
  }
}
