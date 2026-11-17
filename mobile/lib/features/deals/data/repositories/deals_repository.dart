import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/deal_model.dart';

class DealsRepository {
  final ApiClient apiClient;

  DealsRepository({required this.apiClient});

  Future<List<DealModel>> getDeals({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final response = await apiClient.get(
      ApiEndpoints.deals,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => DealModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить сделки');
  }

  Future<DealModel> getDealById(String id) async {
    final response = await apiClient.get(ApiEndpoints.deal(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return DealModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные сделки');
  }

  Future<DealModel> createDeal(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.deals, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return DealModel.fromJson(map);
    }
    throw Exception('Не удалось создать сделку');
  }

  Future<DealModel> updateDealStatus(String id, String status) async {
    final response = await apiClient.patch('${ApiEndpoints.deals}/$id/status', data: {'status': status});
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return DealModel.fromJson(map);
    }
    throw Exception('Не удалось обновить статус сделки');
  }

  Future<void> addComment(String dealId, String text) async {
    final response = await apiClient.post('${ApiEndpoints.deals}/$dealId/comments', data: {'text': text});
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось добавить комментарий');
    }
  }
}
