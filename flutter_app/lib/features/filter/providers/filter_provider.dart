import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/models/filter_model.dart';

part 'filter_provider.g.dart';

@riverpod
class FilterList extends _$FilterList {
  @override
  Future<List<FilterModel>> build(int eventId) async {
    final response = await DioClient.instance.dio.get(
      ApiEndpoints.eventFilters(eventId),
    );
    final data = response.data['data'] as List;
    return data.map((json) => FilterModel.fromJson(json as Map<String, dynamic>)).toList();
  }
}
