import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/shipment_model.dart';

class ShipmentsRepository {
  final ApiClient apiClient;

  ShipmentsRepository({required this.apiClient});

  Future<List<ShipmentModel>> getShipments({String? status, int page = 1, int limit = 50}) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final response = await apiClient.get(
      ApiEndpoints.shipments,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => ShipmentModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить поставки');
  }

  Future<ShipmentModel> getShipmentById(String id) async {
    final response = await apiClient.get(ApiEndpoints.shipment(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ShipmentModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные поставки');
  }

  Future<ShipmentModel> createShipment(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.shipments, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ShipmentModel.fromJson(map);
    }
    throw Exception('Не удалось создать поставку');
  }

  Future<void> confirmShipment(String id) async {
    final response = await apiClient.post(ApiEndpoints.confirmShipment(id));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось подтвердить приёмку');
    }
  }
}
