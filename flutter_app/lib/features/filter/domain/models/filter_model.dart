import 'dart:convert';
import 'package:flutter/material.dart';

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
        try {
          params = jsonDecode(json['parameters'] as String) as Map<String, dynamic>;
        } catch (_) {
          params = null;
        }
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

  /// High-fidelity ColorFilter Matrix for realistic photo styling (Instagram/VSCO style).
  ColorFilter? get colorFilter {
    final type = parameters?['type'] as String? ?? '';
    final nameLower = name.toLowerCase();

    if (type == 'grayscale' || nameLower.contains('b&w') || nameLower.contains('monochrome') || nameLower.contains('hitam')) {
      return const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
    }

    if (type == 'sepia' || nameLower.contains('sepia') || nameLower.contains('vintage')) {
      return const ColorFilter.matrix(<double>[
        0.393, 0.769, 0.189, 0, 10,
        0.349, 0.686, 0.168, 0, 5,
        0.272, 0.534, 0.131, 0, -10,
        0,     0,     0,     1, 0,
      ]);
    }

    if (type == 'warm' || nameLower.contains('warm') || nameLower.contains('coffee')) {
      return const ColorFilter.matrix(<double>[
        1.15, 0,    0,    0, 20,
        0,    1.05, 0,    0, 10,
        0,    0,    0.88, 0, -10,
        0,    0,    0,    1, 0,
      ]);
    }

    if (type == 'cool' || nameLower.contains('cool') || nameLower.contains('mist') || nameLower.contains('blue')) {
      return const ColorFilter.matrix(<double>[
        0.88, 0,    0,    0, -10,
        0,    0.95, 0,    0, 0,
        0,    0,    1.22, 0, 22,
        0,    0,    0,    1, 0,
      ]);
    }

    if (type == 'soft' || nameLower.contains('soft') || nameLower.contains('pastel') || nameLower.contains('glow')) {
      return const ColorFilter.matrix(<double>[
        1.08, 0,    0,    0, 22,
        0,    1.08, 0,    0, 22,
        0,    0,    1.12, 0, 25,
        0,    0,    0,    1, 0,
      ]);
    }

    if (type == 'contrast' || nameLower.contains('contrast') || nameLower.contains('vivid')) {
      return const ColorFilter.matrix(<double>[
        1.35, 0,    0,    0, -22,
        0,    1.35, 0,    0, -22,
        0,    0,    1.35, 0, -22,
        0,    0,    0,    1, 0,
      ]);
    }

    if (type == 'sunset' || nameLower.contains('sunset') || nameLower.contains('golden')) {
      return const ColorFilter.matrix(<double>[
        1.28, 0,    0,    0, 25,
        0,    1.02, 0,    0, 8,
        0,    0,    0.72, 0, -20,
        0,    0,    0,    1, 0,
      ]);
    }

    return null; // Original / None
  }

  /// Backward compatible previewTint
  Color? get previewTint {
    if (parameters == null) return null;
    final type = parameters!['type'] as String?;
    switch (type) {
      case 'none':
        return null;
      case 'grayscale':
        return const Color(0x77808080);
      case 'sepia':
        return const Color(0x33704214);
      case 'warm':
        return const Color(0x28C89B5B);
      case 'cool':
        return const Color(0x284A90E2);
      default:
        return null;
    }
  }
}
