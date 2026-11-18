import '../../../../core/utils/json_helpers.dart';

/// Formats a stock quantity without a trailing ".0" (12, 2.5).
String formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Parses a number typed by the user ("12 000", "2,5"). Returns null when it is not a number.
double? parseAmount(String text) {
  final clean = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

class ProductCategoryModel {
  final String id;
  final String name;

  const ProductCategoryModel({required this.id, required this.name});

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
    );
  }
}

class ProductModel {
  final String id;
  final String sku;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String? description;
  final String? barcode;
  final String unit;
  final double minStockLevel;
  final double sellingPrice;
  final double purchasePrice;

  /// Quantity on stock as reported by the server.
  final double currentStock;
  final double avgCost;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.description,
    this.barcode,
    this.unit = 'шт',
    this.minStockLevel = 0,
    required this.sellingPrice,
    this.purchasePrice = 0,
    this.currentStock = 0,
    this.avgCost = 0,
  });

  bool get isLowStock => currentStock <= minStockLevel;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: JsonHelpers.toStr(json['id']),
      sku: JsonHelpers.toStr(json['sku']),
      name: JsonHelpers.toStr(json['name']),
      categoryId: JsonHelpers.extractOptionalString(json['category_id'] ?? json['categoryId']),
      categoryName: JsonHelpers.extractOptionalString(json['category_name'] ?? json['categoryName']),
      description: JsonHelpers.extractOptionalString(json['description']),
      barcode: JsonHelpers.extractOptionalString(json['barcode']),
      unit: JsonHelpers.toStr(json['unit'], 'шт'),
      minStockLevel: JsonHelpers.toDouble(json['min_stock_level'] ?? json['minStockLevel']),
      sellingPrice: JsonHelpers.toDouble(json['selling_price'] ?? json['sellingPrice']),
      purchasePrice: JsonHelpers.toDouble(json['purchase_price'] ?? json['purchasePrice']),
      currentStock: JsonHelpers.toDouble(json['quantity'] ?? json['current_stock']),
      avgCost: JsonHelpers.toDouble(json['avg_cost'] ?? json['avgCost']),
    );
  }
}

class StockMovementModel {
  final String id;
  final String productId;

  /// INCOMING, OUTGOING or ADJUSTMENT.
  final String type;
  final double quantity;
  final double balanceAfter;
  final String? reason;
  final String? createdByName;
  final DateTime? createdAt;

  /// Signed change of the stock. Null when the direction cannot be derived
  /// (an inventory correction whose previous balance is not in the loaded history).
  final double? delta;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    this.reason,
    this.createdByName,
    this.createdAt,
    this.delta,
  });

  bool get isIncoming => type == 'INCOMING';
  bool get isOutgoing => type == 'OUTGOING';

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    final type = JsonHelpers.toStr(json['type']).toUpperCase();
    final quantity = JsonHelpers.toDouble(json['quantity']);
    return StockMovementModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['product_id'] ?? json['productId']),
      type: type,
      quantity: quantity,
      balanceAfter: JsonHelpers.toDouble(json['balance_after'] ?? json['balanceAfter']),
      reason: JsonHelpers.extractOptionalString(json['reason'] ?? json['notes']),
      createdByName: JsonHelpers.extractOptionalString(json['created_by_name'] ?? json['createdByName']),
      createdAt: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['createdAt']),
      delta: type == 'INCOMING'
          ? quantity
          : type == 'OUTGOING'
              ? -quantity
              : null,
    );
  }

  StockMovementModel withDelta(double value) {
    return StockMovementModel(
      id: id,
      productId: productId,
      type: type,
      quantity: quantity,
      balanceAfter: balanceAfter,
      reason: reason,
      createdByName: createdByName,
      createdAt: createdAt,
      delta: value,
    );
  }

  /// Parses the history of ONE product (newest first, as the server returns it)
  /// and derives the direction of inventory corrections from the neighbouring balances.
  static List<StockMovementModel> listForProduct(List<dynamic> rows, {required bool complete}) {
    final list = rows.map((e) => StockMovementModel.fromJson(JsonHelpers.toMap(e))).toList();
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.delta != null) continue;
      if (i + 1 < list.length) {
        list[i] = m.withDelta(m.balanceAfter - list[i + 1].balanceAfter);
      } else if (complete) {
        list[i] = m.withDelta(m.balanceAfter);
      }
    }
    return list;
  }
}
