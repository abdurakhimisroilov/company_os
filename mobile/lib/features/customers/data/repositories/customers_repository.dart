import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/customer_model.dart';

class CustomersRepository {
  final ApiClient apiClient;

  CustomersRepository({required this.apiClient});

  Future<List<CustomerModel>> getCustomers({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await apiClient.get(
      ApiEndpoints.customers,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => CustomerModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить клиентов');
  }

  Future<CustomerModel> getCustomerById(String id) async {
    final response = await apiClient.get(ApiEndpoints.customer(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return CustomerModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные клиента');
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.customers, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return CustomerModel.fromJson(map);
    }
    throw Exception('Не удалось создать клиента');
  }
}
