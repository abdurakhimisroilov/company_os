import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/product_model.dart';

class InventoryRepository {
  final ApiClient apiClient;

  InventoryRepository({required this.apiClient});

  /// The server caps the movement history at this many rows.
  static const int _movementsCap = 200;

  Map<String, dynamic> _data(dynamic body) {
    return JsonHelpers.toMap(body is Map && body.containsKey('data') ? body['data'] : body);
  }

  Future<List<ProductModel>> getProducts({String? search, String? categoryId}) async {
    final query = <String, dynamic>{'limit': 500};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (categoryId != null && categoryId.isNotEmpty) query['categoryId'] = categoryId;

    final response = await apiClient.get(ApiEndpoints.products, queryParameters: query);
    return JsonHelpers.toList(response.data).map((e) => ProductModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<List<ProductCategoryModel>> getCategories() async {
    final response = await apiClient.get(ApiEndpoints.productCategories);
    return JsonHelpers.toList(response.data)
        .map((e) => ProductCategoryModel.fromJson(JsonHelpers.toMap(e)))
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
        .toList();
  }

  Future<ProductModel> getProductById(String id) async {
    final response = await apiClient.get(ApiEndpoints.product(id));
    return ProductModel.fromJson(_data(response.data));
  }

  Future<List<StockMovementModel>> getStockMovements(String productId) async {
    final response = await apiClient.get(
      ApiEndpoints.stockMovements,
      queryParameters: {'productId': productId},
    );
    final rows = JsonHelpers.toList(response.data);
    return StockMovementModel.listForProduct(rows, complete: rows.length < _movementsCap);
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.products, data: data);
    return ProductModel.fromJson(_data(response.data));
  }

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch(ApiEndpoints.product(id), data: data);
    return ProductModel.fromJson(_data(response.data));
  }

  Future<void> deleteProduct(String id) async {
    await apiClient.delete(ApiEndpoints.product(id));
  }

  /// [type] is 'in' (receive), 'out' (write off) or 'set' (actual counted quantity).
  /// Returns the product with its new quantity.
  Future<ProductModel> adjustStock({
    required String productId,
    required String type,
    required double quantity,
    String? notes,
  }) async {
    final response = await apiClient.post(ApiEndpoints.adjustStock, data: {
      'productId': productId,
      'type': type,
      'quantity': quantity,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return ProductModel.fromJson(_data(response.data));
  }
}
