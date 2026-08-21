import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/models/timer_setting_model.dart';

/// Provider for dynamic timer settings fetched from backend.
/// Automatically falls back to standard default values if backend is unreachable.
final timerSettingProvider = FutureProvider<TimerSettingModel>((ref) async {
  try {
    final response = await DioClient.instance.dio.get(ApiEndpoints.activeTimers);
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        return TimerSettingModel.fromJson(data);
      }
    }
  } catch (_) {
    // Fail gracefully with standard defaults
  }
  return const TimerSettingModel();
});
