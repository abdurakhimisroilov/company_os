import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/product_model.dart';

class InventoryRepository {
  final ApiClient apiClient;

  InventoryRepository({required this.apiClient});

  Future<List<ProductModel>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null && categoryId.isNotEmpty) query['categoryId'] = categoryId;

    final response = await apiClient.get(
      ApiEndpoints.products,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => ProductModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить товары');
  }

  Future<ProductModel> getProductById(String id) async {
    final response = await apiClient.get(ApiEndpoints.product(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ProductModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные товара');
  }

  Future<List<StockMovementModel>> getStockMovements(String productId) async {
    final response = await apiClient.get(
      ApiEndpoints.stockMovements,
      queryParameters: {'productId': productId},
    );
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => StockMovementModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    return [];
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.products, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ProductModel.fromJson(map);
    }
    throw Exception('Не удалось сохранить товар');
  }

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch('${ApiEndpoints.products}/$id', data: data);
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ProductModel.fromJson(map);
    }
    throw Exception('Не удалось обновить товар');
  }

  Future<void> deleteProduct(String id) async {
    final response = await apiClient.delete('${ApiEndpoints.products}/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Не удалось удалить товар');
    }
  }

  Future<void> adjustStock(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.adjustStock, data: data);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Не удалось выполнить корректировку остатка');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await apiClient.get(ApiEndpoints.productCategories);
      if (response.statusCode == 200) {
        final list = JsonHelpers.toList(response.data);
        return list.map((e) => JsonHelpers.extractString(e, fallback: e.toString())).toList();
      }
    } catch (_) {}
    return ['Все', 'Электроника', 'Аксессуары', 'Одежда', 'Оборудование'];
  }
}
