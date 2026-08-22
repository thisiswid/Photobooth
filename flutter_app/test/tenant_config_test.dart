import 'package:flutter_test/flutter_test.dart';
import 'package:fakultas_kopi_photobooth/features/provisioning/models/tenant_config.dart';

void main() {
  group('TenantConfig Serialization & Parsing Tests', () {
    test('Fallback TenantConfig contains valid defaults', () {
      final fallback = TenantConfig.fallback();
      expect(fallback.cafe.name, isNotEmpty);
      expect(fallback.pricing.sessionPrice, greaterThan(0));
      expect(fallback.timers.cameraCountdownSeconds, equals(5));
      expect(fallback.hardware.autoPrint, isTrue);
    });

    test('FromJson parses complete backend response accurately', () {
      final json = {
        'device': {
          'id': 1,
          'name': 'Kiosk Utama',
          'device_key': 'SNAP-FK-8821',
          'platform': 'android',
        },
        'cafe': {
          'id': 10,
          'name': 'Kopi Kenangan Senja',
          'code': 'KKS-01',
          'address': 'Jl. Melati No. 12',
          'logo_url': 'https://server.com/logo.png',
          'is_ai_enabled': false,
          'show_kiosk_settings': true,
          'theme': {
            'primary_color': '#FF5722',
            'accent_color': '#BF360C',
            'background_url': 'https://server.com/bg.jpg',
          },
        },
        'event': {
          'id': 3,
          'name': 'Valentine Special',
        },
        'pricing': {
          'session_price': 35000,
          'currency': 'IDR',
          'default_print_copies': 2,
        },
        'timers': {
          'camera_countdown_seconds': 7,
          'session_timeout_seconds': 600,
          'payment_timeout_seconds': 120,
          'result_screen_timeout_seconds': 45,
          'retake_timeout_seconds': 15,
        },
        'hardware_defaults': {
          'countdown_seconds': 7,
          'max_retakes': 2,
          'auto_print': true,
          'show_kiosk_settings': true,
        },
        'frames': [
          {
            'id': 101,
            'name': 'Frame Romantic Strip',
            'asset_url': 'https://server.com/frame1.png',
            'pose_count': 3,
            'layout_type': 'single',
            'slots': [
              {'x': 50, 'y': 100, 'w': 500, 'h': 350, 'pose_index': 0},
            ],
          }
        ],
        'filters': [
          {
            'id': 201,
            'name': 'Warm Sunset',
            'thumbnail_url': 'https://server.com/thumb.png',
            'parameters': {'warmth': 1.4},
            'sort_order': 1,
          }
        ],
        'screens': {
          'welcome': {
            'title': 'KOPI KENANGAN SENJA',
            'description': 'Abadikan Momen Manismu',
            'button_text': 'Mulai Foto Sekarang',
          }
        }
      };

      final config = TenantConfig.fromJson(json);

      expect(config.device?.deviceKey, equals('SNAP-FK-8821'));
      expect(config.cafe.name, equals('Kopi Kenangan Senja'));
      expect(config.cafe.code, equals('KKS-01'));
      expect(config.cafe.isAiEnabled, isFalse);
      expect(config.event?.name, equals('Valentine Special'));
      expect(config.pricing.sessionPrice, equals(35000));
      expect(config.timers.cameraCountdownSeconds, equals(7));
      expect(config.timers.paymentTimeoutSeconds, equals(120));
      expect(config.frames.length, equals(1));
      expect(config.frames.first.name, equals('Frame Romantic Strip'));
      expect(config.filters.length, equals(1));
      expect(config.filters.first.name, equals('Warm Sunset'));
      expect(config.screens['welcome']?['title'], equals('KOPI KENANGAN SENJA'));

      // Test roundtrip toJson
      final roundtrip = config.toJson();
      expect(roundtrip['cafe']['name'], equals('Kopi Kenangan Senja'));
      expect(roundtrip['pricing']['session_price'], equals(35000));
    });

    test('ThemeConfig parses HEX colors correctly', () {
      const theme = ThemeConfig(
        primaryColorHex: '#FF5722',
        accentColorHex: '#BF360C',
      );

      expect(theme.primaryColor.value, equals(0xFFFF5722));
      expect(theme.accentColor.value, equals(0xFFBF360C));
    });

    test('ThemeConfig fallback handles null or invalid HEX safely', () {
      const invalidTheme = ThemeConfig(
        primaryColorHex: 'invalid-hex',
        accentColorHex: '',
      );

      expect(invalidTheme.primaryColor.value, equals(0xFFD97706));
      expect(invalidTheme.accentColor.value, equals(0xFF78350F));
    });
  });
}
