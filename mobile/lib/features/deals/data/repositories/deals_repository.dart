import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/deal_model.dart';

class DealsRepository {
  final ApiClient apiClient;

  DealsRepository({required this.apiClient});

  Map<String, dynamic> _data(dynamic body) =>
      JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);

  Future<List<DealModel>> getDeals({String? status, String? search}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final response = await apiClient.get(ApiEndpoints.deals, queryParameters: query);
    final list = JsonHelpers.toList(response.data);
    return list.map((e) => DealModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// Deal with its comments.
  Future<DealModel> getDealById(String id) async {
    final response = await apiClient.get(ApiEndpoints.deal(id));
    return DealModel.fromJson(_data(response.data));
  }

  /// Body: title, customerId | customerName, amount, status, description, expectedCloseDate (yyyy-MM-dd).
  Future<DealModel> createDeal(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.deals, data: data);
    return DealModel.fromJson(_data(response.data));
  }

  /// Body: any of title, amount, description, expectedCloseDate (yyyy-MM-dd or null), status.
  Future<DealModel> updateDeal(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch(ApiEndpoints.deal(id), data: data);
    return DealModel.fromJson(_data(response.data));
  }

  Future<DealModel> updateDealStatus(String id, String status) async {
    final response = await apiClient.patch(ApiEndpoints.dealStatus(id), data: {'status': status});
    return DealModel.fromJson(_data(response.data));
  }

  Future<void> deleteDeal(String id) async {
    await apiClient.delete(ApiEndpoints.deal(id));
  }

  Future<DealCommentModel> addComment(String dealId, String text) async {
    final response = await apiClient.post(ApiEndpoints.dealComments(dealId), data: {'text': text});
    return DealCommentModel.fromJson(_data(response.data));
  }
}
