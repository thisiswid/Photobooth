import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/provisioning_service.dart';
import '../models/tenant_config.dart';

/// State Notifier untuk mengelola status Tenant & Konfigurasi Kiosk
class TenantNotifier extends StateNotifier<AsyncValue<TenantConfig>> {
  TenantNotifier(this._service) : super(const AsyncValue.loading()) {
    init();
  }

  final ProvisioningService _service;

  /// Inisialisasi awal saat aplikasi start
  Future<void> init() async {
    state = const AsyncValue.loading();
    try {
      final isProvisioned = await _service.isDeviceProvisioned();
      if (!isProvisioned) {
        // Cek apakah ada cache offline sebelumnya
        final cached = await _service.getCachedConfig();
        if (cached != null) {
          state = AsyncValue.data(cached);
        } else {
          // Belum pernah di-provision sama sekali
          state = AsyncValue.data(TenantConfig.fallback());
        }
        return;
      }

      // Jika sudah ada device key, fetch config terbaru dari cloud/cache
      final config = await _service.fetchConfig();
      state = AsyncValue.data(config);
    } catch (e, st) {
      // Jika terjadi error (misal no internet), fallback ke cache
      final cached = await _service.getCachedConfig();
      if (cached != null) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Aktivasi / Pairing Device Key baru
  Future<TenantConfig> activateDevice({
    required String deviceKey,
    String? customBaseUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final config = await _service.activateDevice(
        deviceKey: deviceKey,
        customBaseUrl: customBaseUrl,
      );
      state = AsyncValue.data(config);
      return config;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sync ulang konfigurasi dari server
  Future<void> refreshConfig() async {
    try {
      final config = await _service.fetchConfig();
      state = AsyncValue.data(config);
    } catch (e) {
      // Biarkan state lama tetap aktif jika refresh gagal
    }
  }

  /// Reset / Unpair Device
  Future<void> unpairDevice() async {
    await _service.unpairDevice();
    state = AsyncValue.data(TenantConfig.fallback());
  }

  /// Cek apakah perangkat sudah di-pairing
  Future<bool> checkIsProvisioned() async {
    return await _service.isDeviceProvisioned();
  }
}

/// Provider Global untuk Tenant Configuration
final tenantNotifierProvider =
    StateNotifierProvider<TenantNotifier, AsyncValue<TenantConfig>>((ref) {
  return TenantNotifier(ProvisioningService.instance);
});

/// Helper Provider untuk mengecek apakah device sudah ter-provision
final isDeviceProvisionedProvider = FutureProvider<bool>((ref) async {
  return await ProvisioningService.instance.isDeviceProvisioned();
});
