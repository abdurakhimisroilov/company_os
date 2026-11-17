import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final ApiClient apiClient;

  SalesRepository({required this.apiClient});

  Future<List<SaleModel>> getSales({String? status, int page = 1, int limit = 50}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final response = await apiClient.get(
      ApiEndpoints.sales,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => SaleModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить продажи');
  }

  Future<SaleModel> getSaleById(String id) async {
    final response = await apiClient.get(ApiEndpoints.sale(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return SaleModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные продажи');
  }

  Future<SaleModel> createSale(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.sales, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return SaleModel.fromJson(map);
    }
    throw Exception('Не удалось сохранить продажу');
  }

  Future<void> addPayment(String saleId, double amount, String method) async {
    final response = await apiClient.post(
      ApiEndpoints.salePayment(saleId),
      data: {'amount': amount, 'method': method},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось провести платёж');
    }
  }
}
