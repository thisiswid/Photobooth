import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/models/frame_model.dart';

part 'frame_provider.g.dart';

@riverpod
class FrameList extends _$FrameList {
  @override
  Future<List<FrameModel>> build(int eventId) async {
    final response = await DioClient.instance.dio.get(
      ApiEndpoints.eventFrames(eventId),
    );
    final data = response.data['data'] as List;
    return data.map((json) => FrameModel.fromJson(json as Map<String, dynamic>)).toList();
  }
}
