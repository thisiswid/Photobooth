import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../provisioning/providers/tenant_provider.dart';
import '../domain/models/frame_model.dart';

part 'frame_provider.g.dart';

// ── Mock data — Phase 1 fallback when backend is not available ────────────────

const _mockFrames = [
  FrameModel(id: 1, name: 'Classic Gold',  poseCount: 4),
  FrameModel(id: 2, name: 'Coffee Brown',  poseCount: 4),
  FrameModel(id: 3, name: 'Midnight',      poseCount: 2),
  FrameModel(id: 4, name: 'Rose Gold',     poseCount: 4),
  FrameModel(id: 5, name: 'Forest',        poseCount: 4),
  FrameModel(id: 6, name: 'Minimal White', poseCount: 2),
];

// ── Provider ──────────────────────────────────────────────────────────────────

@riverpod
class FrameList extends _$FrameList {
  @override
  Future<List<FrameModel>> build(int eventId) async {
    // 1. Cek apakah ada frame dari Tenant Config aktif
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    if (tenantConfig != null && tenantConfig.frames.isNotEmpty) {
      return tenantConfig.frames.map((f) {
        return FrameModel.fromJson(f.toJson());
      }).toList();
    }

    // 2. Jika tidak ada, fetch dari API Event Frames
    try {
      final response = await DioClient.instance.dio.get(
        ApiEndpoints.eventFrames(eventId),
      );
      final data = response.data['data'] as List;
      return data
          .map((json) => FrameModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      // Backend not reachable — return mock data for Phase 1 development.
      return _mockFrames;
    } catch (_) {
      return _mockFrames;
    }
  }
}
