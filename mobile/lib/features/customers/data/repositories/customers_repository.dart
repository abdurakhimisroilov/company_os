import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/customer_model.dart';

class CustomersRepository {
  final ApiClient apiClient;

  CustomersRepository({required this.apiClient});

  Map<String, dynamic> _data(dynamic body) =>
      JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);

  Future<List<CustomerModel>> getCustomers({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final response = await apiClient.get(ApiEndpoints.customers, queryParameters: query);
    final list = JsonHelpers.toList(response.data);
    return list.map((e) => CustomerModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// Customer card with sales history (`sales`), `totalPurchases` and `balance`.
  Future<CustomerModel> getCustomerById(String id) async {
    final response = await apiClient.get(ApiEndpoints.customer(id));
    return CustomerModel.fromJson(_data(response.data));
  }

  /// Body: name, phone, email, address.
  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.customers, data: data);
    return CustomerModel.fromJson(_data(response.data));
  }

  Future<CustomerModel> updateCustomer(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch(ApiEndpoints.customer(id), data: data);
    return CustomerModel.fromJson(_data(response.data));
  }

  /// The server refuses while the customer still owes money.
  Future<void> deleteCustomer(String id) async {
    await apiClient.delete(ApiEndpoints.customer(id));
  }
}
