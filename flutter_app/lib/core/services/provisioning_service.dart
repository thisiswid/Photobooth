import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../../features/provisioning/models/tenant_config.dart';

/// Service untuk aktivasi mesin (Device Provisioning) & sinkronisasi konfigurasi tenant.
class ProvisioningService {
  ProvisioningService._();
  static final ProvisioningService instance = ProvisioningService._();

  static const _storage = FlutterSecureStorage();
  static const _keyDeviceKey = 'provisioning_device_key';
  static const _keyDeviceId = 'provisioning_device_id';
  static const _keyTenantConfig = 'provisioning_tenant_config_cache';
  static const _keyCustomBaseUrl = 'provisioning_custom_base_url';

  TenantConfig? _cachedConfig;

  // ─── Getters ───────────────────────────────────────────────────────────────

  Future<String?> getDeviceKey() async {
    try {
      return await _storage.read(key: _keyDeviceKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCustomBaseUrl() async {
    try {
      return await _storage.read(key: _keyCustomBaseUrl);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isDeviceProvisioned() async {
    final key = await getDeviceKey();
    return key != null && key.trim().isNotEmpty;
  }

  // ─── Cache Management ─────────────────────────────────────────────────────

  Future<TenantConfig?> getCachedConfig() async {
    if (_cachedConfig != null) return _cachedConfig;
    try {
      final jsonStr = await _storage.read(key: _keyTenantConfig);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _cachedConfig = TenantConfig.fromJson(data);
        return _cachedConfig;
      }
    } catch (e) {
      debugPrint('⚠️ Gagal membaca cached TenantConfig: $e');
    }
    return null;
  }

  Future<void> saveConfig(TenantConfig config) async {
    _cachedConfig = config;
    try {
      final jsonStr = jsonEncode(config.toJson());
      await _storage.write(key: _keyTenantConfig, value: jsonStr);
    } catch (e) {
      debugPrint('⚠️ Gagal menyimpan cached TenantConfig: $e');
    }
  }

  // ─── Aktivasi Mesin (Pairing) ─────────────────────────────────────────────

  Future<TenantConfig> activateDevice({
    required String deviceKey,
    String? customBaseUrl,
  }) async {
    final cleanKey = deviceKey.trim();
    if (cleanKey.isEmpty) {
      throw const ValidationException(message: 'Device Key tidak boleh kosong.');
    }

    if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
      final url = customBaseUrl.trim();
      await _storage.write(key: _keyCustomBaseUrl, value: url);
      DioClient.instance.updateBaseUrl(url);
    }

    try {
      // 1. Panggil Endpoint Aktivasi Mesin
      final activateResponse = await DioClient.instance.safeRequest(
        () => DioClient.instance.dio.post(
          ApiEndpoints.deviceActivate,
          data: {
            'device_key': cleanKey,
            'platform': 'android',
            'app_version': AppConstants.appVersion,
          },
        ),
      );

      final actData = activateResponse.data;
      if (actData['success'] != true) {
        throw ServerException(
          message: actData['message'] ?? 'Aktivasi perangkat gagal.',
          statusCode: activateResponse.statusCode,
        );
      }

      // 2. Fetch Konfigurasi Lengkap dari Server
      final configResponse = await DioClient.instance.safeRequest(
        () => DioClient.instance.dio.get(
          ApiEndpoints.deviceConfig(cleanKey),
        ),
      );

      final confData = configResponse.data;
      if (confData['success'] != true || confData['data'] == null) {
        throw ServerException(
          message: confData['message'] ?? 'Gagal mengambil konfigurasi tenant.',
          statusCode: configResponse.statusCode,
        );
      }

      final Map<String, dynamic> rawConfig = confData['data'] as Map<String, dynamic>;
      
      // Sisipkan info device jika ada dari respon aktivasi
      if (actData['data']?['device'] != null) {
        rawConfig['device'] = actData['data']['device'];
      }

      final config = TenantConfig.fromJson(rawConfig);

      // 3. Simpan ke Secure Storage
      await _storage.write(key: _keyDeviceKey, value: cleanKey);
      if (config.device?.id != null) {
        await _storage.write(key: _keyDeviceId, value: config.device!.id.toString());
      }
      await saveConfig(config);

      debugPrint('✅ Mesin berhasil di-pairing ke Cafe: ${config.cafe.name} (${config.cafe.code})');
      return config;
    } catch (e) {
      debugPrint('❌ Error saat aktivasi device: $e');
      rethrow;
    }
  }

  // ─── Fetch / Sync Konfigurasi Terkini ──────────────────────────────────────

  Future<TenantConfig> fetchConfig({String? deviceKey}) async {
    final key = deviceKey ?? await getDeviceKey();
    if (key == null || key.trim().isEmpty) {
      final cached = await getCachedConfig();
      if (cached != null) return cached;
      return TenantConfig.fallback();
    }

    try {
      final configResponse = await DioClient.instance.safeRequest(
        () => DioClient.instance.dio.get(
          ApiEndpoints.deviceConfig(key.trim()),
        ),
      );

      final confData = configResponse.data;
      if (confData['success'] == true && confData['data'] != null) {
        final config = TenantConfig.fromJson(confData['data'] as Map<String, dynamic>);
        await saveConfig(config);
        return config;
      }
    } catch (e) {
      debugPrint('⚠️ Fetch config gagal (mungkin offline), menggunakan cache: $e');
    }

    // Fallback ke cache jika offline
    final cached = await getCachedConfig();
    return cached ?? TenantConfig.fallback();
  }

  // ─── Unpair / Reset Device ────────────────────────────────────────────────

  Future<void> unpairDevice() async {
    _cachedConfig = null;
    try {
      await _storage.delete(key: _keyDeviceKey);
      await _storage.delete(key: _keyDeviceId);
      await _storage.delete(key: _keyTenantConfig);
      debugPrint('🔄 Device berhasil di-unpair / di-reset.');
    } catch (e) {
      debugPrint('⚠️ Gagal menghapus storage saat unpair: $e');
    }
  }
}
