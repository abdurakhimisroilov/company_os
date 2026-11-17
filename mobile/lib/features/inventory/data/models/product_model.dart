import '../../../../core/utils/json_helpers.dart';

class ProductModel {
  final String id;
  final String sku;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String? description;
  final String? barcode;
  final List<String> images;
  final String unit;
  final double minStockLevel;
  final double sellingPrice;
  final double purchasePrice;
  final double currentStock;
  final double avgCost;
  final bool isActive;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.description,
    this.barcode,
    this.images = const [],
    this.unit = 'шт',
    this.minStockLevel = 0,
    required this.sellingPrice,
    this.purchasePrice = 0,
    this.currentStock = 0,
    this.avgCost = 0,
    this.isActive = true,
  });

  bool get isLowStock => currentStock <= minStockLevel;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imgs = JsonHelpers.toList(json['images'])
        .map((e) => e.toString())
        .toList();

    return ProductModel(
      id: JsonHelpers.toStr(json['id']),
      sku: JsonHelpers.toStr(json['sku']),
      name: JsonHelpers.toStr(json['name'], 'Товар'),
      categoryId: JsonHelpers.extractOptionalString(json['categoryId'] ?? json['category_id']),
      categoryName: JsonHelpers.extractOptionalString(
            json['category'],
            preferredKeys: ['name', 'title'],
          ) ??
          JsonHelpers.extractOptionalString(json['categoryName'] ?? json['category_name']),
      description: JsonHelpers.extractOptionalString(json['description']),
      barcode: JsonHelpers.extractOptionalString(json['barcode']),
      images: imgs,
      unit: JsonHelpers.toStr(json['unit'], 'шт'),
      minStockLevel: JsonHelpers.toDouble(json['minStockLevel'] ?? json['min_stock_level']),
      sellingPrice: JsonHelpers.toDouble(json['sellingPrice'] ?? json['selling_price'] ?? json['price']),
      purchasePrice: JsonHelpers.toDouble(json['purchasePrice'] ?? json['purchase_price'] ?? json['costPrice']),
      currentStock: JsonHelpers.toDouble(
        json['currentStock'] ??
            json['quantity'] ??
            (json['inventory'] is Map ? json['inventory']['quantity'] : null),
      ),
      avgCost: JsonHelpers.toDouble(
        json['avgCost'] ??
            json['average_cost'] ??
            (json['inventory'] is Map ? json['inventory']['average_cost'] : null),
      ),
      isActive: JsonHelpers.toBool(json['isActive'] ?? json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'categoryId': categoryId,
      'description': description,
      'barcode': barcode,
      'images': images,
      'unit': unit,
      'minStockLevel': minStockLevel,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'isActive': isActive,
    };
  }
}

class StockMovementModel {
  final String id;
  final String productId;
  final String type; // 'in', 'out', 'adjustment', 'transfer'
  final double quantity;
  final double unitCost;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.unitCost,
    this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['productId'] ?? json['product_id']),
      type: JsonHelpers.toStr(json['type'], 'in').toLowerCase(),
      quantity: JsonHelpers.toDouble(json['quantity']),
      unitCost: JsonHelpers.toDouble(json['unitCost'] ?? json['unit_cost'] ?? json['balance_after']),
      referenceType: JsonHelpers.extractOptionalString(json['referenceType'] ?? json['reference_type']),
      referenceId: JsonHelpers.extractOptionalString(json['referenceId'] ?? json['reference_id']),
      notes: JsonHelpers.extractOptionalString(json['notes'] ?? json['reason']),
      createdAt: JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}
