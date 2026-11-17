import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/supplier_model.dart';

class SuppliersRepository {
  final ApiClient apiClient;

  SuppliersRepository({required this.apiClient});

  Future<List<SupplierModel>> getSuppliers({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await apiClient.get(
      ApiEndpoints.suppliers,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => SupplierModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить поставщиков');
  }

  Future<SupplierModel> getSupplierById(String id) async {
    final response = await apiClient.get(ApiEndpoints.supplier(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return SupplierModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные поставщика');
  }

  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.suppliers, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return SupplierModel.fromJson(map);
    }
    throw Exception('Не удалось добавить поставщика');
  }
}
