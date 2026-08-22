import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Konfigurasi Lengkap Multi-Tenant untuk Kiosk SnapTechBooth.
class TenantConfig {
  final DeviceModel? device;
  final CafeModel cafe;
  final EventInfo? event;
  final PricingConfig pricing;
  final TimerConfig timers;
  final HardwareConfig hardware;
  final List<FrameItem> frames;
  final List<FilterItem> filters;
  final Map<String, dynamic> screens;

  const TenantConfig({
    this.device,
    required this.cafe,
    this.event,
    required this.pricing,
    required this.timers,
    required this.hardware,
    this.frames = const [],
    this.filters = const [],
    this.screens = const {},
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    return TenantConfig(
      device: json['device'] != null ? DeviceModel.fromJson(json['device'] as Map<String, dynamic>) : null,
      cafe: json['cafe'] != null
          ? CafeModel.fromJson(json['cafe'] as Map<String, dynamic>)
          : CafeModel.fallback(),
      event: json['event'] != null ? EventInfo.fromJson(json['event'] as Map<String, dynamic>) : null,
      pricing: json['pricing'] != null
          ? PricingConfig.fromJson(json['pricing'] as Map<String, dynamic>)
          : const PricingConfig(),
      timers: json['timers'] != null
          ? TimerConfig.fromJson(json['timers'] as Map<String, dynamic>)
          : const TimerConfig(),
      hardware: json['hardware_defaults'] != null
          ? HardwareConfig.fromJson(json['hardware_defaults'] as Map<String, dynamic>)
          : const HardwareConfig(),
      frames: (json['frames'] as List<dynamic>?)
              ?.map((e) => FrameItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      filters: (json['filters'] as List<dynamic>?)
              ?.map((e) => FilterItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      screens: (json['screens'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (device != null) 'device': device!.toJson(),
      'cafe': cafe.toJson(),
      if (event != null) 'event': event!.toJson(),
      'pricing': pricing.toJson(),
      'timers': timers.toJson(),
      'hardware_defaults': hardware.toJson(),
      'frames': frames.map((f) => f.toJson()).toList(),
      'filters': filters.map((f) => f.toJson()).toList(),
      'screens': screens,
    };
  }

  /// Default Fallback jika belum pernah sync atau berjalan offline pertama kali
  factory TenantConfig.fallback() {
    return TenantConfig(
      cafe: CafeModel.fallback(),
      pricing: const PricingConfig(),
      timers: const TimerConfig(),
      hardware: const HardwareConfig(),
      frames: const [],
      filters: const [],
    );
  }
}

/// Identitas Device Fisik
class DeviceModel {
  final int? id;
  final String name;
  final String deviceKey;
  final String platform;

  const DeviceModel({
    this.id,
    required this.name,
    required this.deviceKey,
    this.platform = 'android',
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? 'Kiosk',
      deviceKey: json['device_key'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'device_key': deviceKey,
      'platform': platform,
    };
  }
}

/// Identitas Cafe / Tenant Pemilik
class CafeModel {
  final int id;
  final String name;
  final String code;
  final String? address;
  final String? logoUrl;
  final bool isAiEnabled;
  final bool showKioskSettings;
  final ThemeConfig theme;

  const CafeModel({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.logoUrl,
    this.isAiEnabled = true,
    this.showKioskSettings = true,
    required this.theme,
  });

  factory CafeModel.fromJson(Map<String, dynamic> json) {
    return CafeModel(
      id: json['id'] as int? ?? 1,
      name: json['name'] as String? ?? AppConstants.defaultCafeBrandName,
      code: json['code'] as String? ?? 'DEFAULT',
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      isAiEnabled: json['is_ai_enabled'] as bool? ?? true,
      showKioskSettings: json['show_kiosk_settings'] as bool? ?? true,
      theme: json['theme'] != null
          ? ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>)
          : ThemeConfig.fallback(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'logo_url': logoUrl,
      'is_ai_enabled': isAiEnabled,
      'show_kiosk_settings': showKioskSettings,
      'theme': theme.toJson(),
    };
  }

  factory CafeModel.fallback() {
    return CafeModel(
      id: 1,
      name: AppConstants.defaultCafeBrandName,
      code: 'DEFAULT',
      theme: ThemeConfig.fallback(),
    );
  }
}

/// Konfigurasi Palet Warna & Tema Cafe
class ThemeConfig {
  final String primaryColorHex;
  final String accentColorHex;
  final String? backgroundUrl;

  const ThemeConfig({
    required this.primaryColorHex,
    required this.accentColorHex,
    this.backgroundUrl,
  });

  Color get primaryColor => _parseHex(primaryColorHex, const Color(0xFFD97706));
  Color get accentColor => _parseHex(accentColorHex, const Color(0xFF78350F));

  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      String cleanHex = hex.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      primaryColorHex: json['primary_color'] as String? ?? '#D97706',
      accentColorHex: json['accent_color'] as String? ?? '#78350F',
      backgroundUrl: json['background_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_color': primaryColorHex,
      'accent_color': accentColorHex,
      'background_url': backgroundUrl,
    };
  }

  factory ThemeConfig.fallback() {
    return const ThemeConfig(
      primaryColorHex: '#D97706',
      accentColorHex: '#78350F',
    );
  }
}

/// Informasi Event Terkait
class EventInfo {
  final int id;
  final String name;

  const EventInfo({required this.id, required this.name});

  factory EventInfo.fromJson(Map<String, dynamic> json) {
    return EventInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Konfigurasi Harga Sesi
class PricingConfig {
  final int sessionPrice;
  final String currency;
  final int defaultPrintCopies;

  const PricingConfig({
    this.sessionPrice = 25000,
    this.currency = 'IDR',
    this.defaultPrintCopies = 2,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      sessionPrice: json['session_price'] as int? ?? 25000,
      currency: json['currency'] as String? ?? 'IDR',
      defaultPrintCopies: json['default_print_copies'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_price': sessionPrice,
      'currency': currency,
      'default_print_copies': defaultPrintCopies,
    };
  }
}

/// Konfigurasi Timer Dinamis
class TimerConfig {
  final int cameraCountdownSeconds;
  final int sessionTimeoutSeconds;
  final int paymentTimeoutSeconds;
  final int resultScreenTimeoutSeconds;
  final int retakeTimeoutSeconds;

  const TimerConfig({
    this.cameraCountdownSeconds = 5,
    this.sessionTimeoutSeconds = 300,
    this.paymentTimeoutSeconds = 180,
    this.resultScreenTimeoutSeconds = 60,
    this.retakeTimeoutSeconds = 10,
  });

  factory TimerConfig.fromJson(Map<String, dynamic> json) {
    return TimerConfig(
      cameraCountdownSeconds: json['camera_countdown_seconds'] as int? ?? 5,
      sessionTimeoutSeconds: json['session_timeout_seconds'] as int? ?? 300,
      paymentTimeoutSeconds: json['payment_timeout_seconds'] as int? ?? 180,
      resultScreenTimeoutSeconds: json['result_screen_timeout_seconds'] as int? ?? 60,
      retakeTimeoutSeconds: json['retake_timeout_seconds'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera_countdown_seconds': cameraCountdownSeconds,
      'session_timeout_seconds': sessionTimeoutSeconds,
      'payment_timeout_seconds': paymentTimeoutSeconds,
      'result_screen_timeout_seconds': resultScreenTimeoutSeconds,
      'retake_timeout_seconds': retakeTimeoutSeconds,
    };
  }
}

/// Konfigurasi Hardware Defaults
class HardwareConfig {
  final int countdownSeconds;
  final int maxRetakes;
  final bool autoPrint;
  final bool showKioskSettings;

  const HardwareConfig({
    this.countdownSeconds = 5,
    this.maxRetakes = 1,
    this.autoPrint = true,
    this.showKioskSettings = true,
  });

  factory HardwareConfig.fromJson(Map<String, dynamic> json) {
    return HardwareConfig(
      countdownSeconds: json['countdown_seconds'] as int? ?? 5,
      maxRetakes: json['max_retakes'] as int? ?? 1,
      autoPrint: json['auto_print'] as bool? ?? true,
      showKioskSettings: json['show_kiosk_settings'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'countdown_seconds': countdownSeconds,
      'max_retakes': maxRetakes,
      'auto_print': autoPrint,
      'show_kiosk_settings': showKioskSettings,
    };
  }
}

/// Item Frame Dinamis
class FrameItem {
  final int id;
  final String name;
  final String? assetUrl;
  final int poseCount;
  final String layoutType;
  final List<dynamic> slots;
  final List<dynamic>? rightColumnOrder;

  const FrameItem({
    required this.id,
    required this.name,
    this.assetUrl,
    this.poseCount = 4,
    this.layoutType = 'single',
    this.slots = const [],
    this.rightColumnOrder,
  });

  factory FrameItem.fromJson(Map<String, dynamic> json) {
    return FrameItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Frame',
      assetUrl: json['asset_url'] as String?,
      poseCount: json['pose_count'] as int? ?? 4,
      layoutType: json['layout_type'] as String? ?? 'single',
      slots: (json['slots'] as List<dynamic>?) ?? const [],
      rightColumnOrder: json['right_column_order'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset_url': assetUrl,
      'pose_count': poseCount,
      'layout_type': layoutType,
      'slots': slots,
      'right_column_order': rightColumnOrder,
    };
  }
}

/// Item Filter Dinamis
class FilterItem {
  final int id;
  final String name;
  final String? thumbnailUrl;
  final Map<String, dynamic>? parameters;
  final int sortOrder;

  const FilterItem({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.parameters,
    this.sortOrder = 0,
  });

  factory FilterItem.fromJson(Map<String, dynamic> json) {
    return FilterItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Filter',
      thumbnailUrl: json['thumbnail_url'] as String?,
      parameters: json['parameters'] is Map<String, dynamic>
          ? json['parameters'] as Map<String, dynamic>
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'thumbnail_url': thumbnailUrl,
      'parameters': parameters,
      'sort_order': sortOrder,
    };
  }
}
