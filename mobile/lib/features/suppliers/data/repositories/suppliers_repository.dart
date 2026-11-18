import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/supplier_model.dart';

class SuppliersRepository {
  final ApiClient apiClient;

  SuppliersRepository({required this.apiClient});

  Map<String, dynamic> _data(dynamic body) =>
      JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);

  Future<List<SupplierModel>> getSuppliers({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final response = await apiClient.get(ApiEndpoints.suppliers, queryParameters: query);
    final list = JsonHelpers.toList(response.data);
    return list.map((e) => SupplierModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// Supplier card with shipment history (`shipments`), `totalPurchases` and `balance`.
  Future<SupplierModel> getSupplierById(String id) async {
    final response = await apiClient.get(ApiEndpoints.supplier(id));
    return SupplierModel.fromJson(_data(response.data));
  }

  /// Body: name, contactPerson, phone, email, address.
  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.suppliers, data: data);
    return SupplierModel.fromJson(_data(response.data));
  }

  Future<SupplierModel> updateSupplier(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch(ApiEndpoints.supplier(id), data: data);
    return SupplierModel.fromJson(_data(response.data));
  }

  /// The server refuses while a debt to the supplier is outstanding.
  Future<void> deleteSupplier(String id) async {
    await apiClient.delete(ApiEndpoints.supplier(id));
  }
}
