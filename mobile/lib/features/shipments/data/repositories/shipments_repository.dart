import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/shipment_model.dart';

class ShipmentsRepository {
  final ApiClient apiClient;

  ShipmentsRepository({required this.apiClient});

  ShipmentModel _shipment(dynamic body) {
    return ShipmentModel.fromJson(JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body));
  }

  /// [status] is 'pending', 'received' or 'all'.
  Future<List<ShipmentModel>> getShipments({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;

    final response = await apiClient.get(ApiEndpoints.shipments, queryParameters: query);
    return JsonHelpers.toList(response.data).map((e) => ShipmentModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  /// Shipment with its items.
  Future<ShipmentModel> getShipmentById(String id) async {
    final response = await apiClient.get(ApiEndpoints.shipment(id));
    return _shipment(response.data);
  }

  /// [data]: `{supplierId | supplierName, invoiceNumber?, expectedDate?, items: [{productId, quantity, unitPrice}],
  /// additionalCosts?, status?: 'pending'}`. Without `status: 'pending'` the goods go to stock at once.
  Future<ShipmentModel> createShipment(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.shipments, data: data);
    return _shipment(response.data);
  }

  /// Receives a pending shipment into stock and returns it updated.
  Future<ShipmentModel> confirmShipment(String id) async {
    final response = await apiClient.post(ApiEndpoints.confirmShipment(id));
    return _shipment(response.data);
  }
}
