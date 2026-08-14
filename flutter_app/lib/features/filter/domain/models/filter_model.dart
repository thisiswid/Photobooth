import 'dart:convert';
import 'dart:ui' show Color;

class FilterModel {
  final int id;
  final String name;
  final String? thumbnailUrl;
  final Map<String, dynamic>? parameters;
  final int sortOrder;

  const FilterModel({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.parameters,
    this.sortOrder = 0,
  });

  factory FilterModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? params;
    if (json['parameters'] != null) {
      if (json['parameters'] is String) {
        params = jsonDecode(json['parameters'] as String) as Map<String, dynamic>;
      } else if (json['parameters'] is Map) {
        params = Map<String, dynamic>.from(json['parameters'] as Map);
      }
    }
    return FilterModel(
      id: json['id'] as int,
      name: json['name'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      parameters: params,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  /// Returns Color tint for preview overlay based on filter parameters.
  /// This is used in Flutter for real-time preview before the final
  /// backend processing.
  Color? get previewTint {
    if (parameters == null) return null;
    final type = parameters!['type'] as String?;
    switch (type) {
      case 'none':
        return null;
      case 'grayscale':
        return const Color(0x99808080);
      case 'colorize':
        final r = (parameters!['r'] as num?)?.toInt() ?? 0;
        final g = (parameters!['g'] as num?)?.toInt() ?? 0;
        final b = (parameters!['b'] as num?)?.toInt() ?? 0;
        return Color.fromARGB(
          50,
          (128 + r).clamp(0, 255),
          (128 + g).clamp(0, 255),
          (128 + b).clamp(0, 255),
        );
      case 'sepia':
        return const Color(0x44704214);
      case 'contrast':
        return const Color(0x22000000);
      case 'soft':
        return const Color(0x18FFFFFF);
      default:
        return null;
    }
  }
}
