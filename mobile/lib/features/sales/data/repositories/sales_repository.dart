import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final ApiClient apiClient;

  SalesRepository({required this.apiClient});

  SaleModel _sale(dynamic body) {
    return SaleModel.fromJson(JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body));
  }

  /// [status] is 'paid', 'partial', 'unpaid' or 'all'.
  Future<List<SaleModel>> getSales({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;

    final response = await apiClient.get(ApiEndpoints.sales, queryParameters: query);
    return JsonHelpers.toList(response.data).map((e) => SaleModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// Sale with its items and payments.
  Future<SaleModel> getSaleById(String id) async {
    final response = await apiClient.get(ApiEndpoints.sale(id));
    return _sale(response.data);
  }

  /// [data]: `{customerId | customerName, items: [{productId, quantity, price}], paidAmount, paymentMethod, discount?}`.
  Future<SaleModel> createSale(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.sales, data: data);
    return _sale(response.data);
  }

  /// Registers a payment and returns the updated sale.
  Future<SaleModel> addPayment(String saleId, double amount, String method) async {
    final response = await apiClient.post(
      ApiEndpoints.salePayment(saleId),
      data: {'amount': amount, 'paymentMethod': method},
    );
    return _sale(response.data);
  }
}
