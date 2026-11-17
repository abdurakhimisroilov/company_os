import '../../../../core/utils/json_helpers.dart';

class ShipmentItemModel {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const ShipmentItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ShipmentItemModel.fromJson(Map<String, dynamic> json) {
    final qty = JsonHelpers.toDouble(json['quantity']);
    final price = JsonHelpers.toDouble(json['unitPrice'] ?? json['purchase_price'] ?? json['price']);
    final total = JsonHelpers.toDouble(json['totalPrice'] ?? json['total_amount'] ?? (qty * price));

    return ShipmentItemModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['productId'] ?? json['product_id']),
      productName: JsonHelpers.extractString(
        json['product'],
        preferredKeys: ['name', 'title'],
        fallback: JsonHelpers.toStr(json['productName'], 'Товар'),
      ),
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}

class ShipmentModel {
  final String id;
  final String supplierId;
  final String supplierName;
  final String invoiceNumber;
  final DateTime expectedDate;
  final DateTime? receivedDate;
  final String status; // 'pending' (Ожидается) | 'received' (Получено) | 'partial' (Частично)
  final double totalCost;
  final double additionalCosts;
  final String? responsibleEmployee;
  final List<ShipmentItemModel> items;

  const ShipmentModel({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNumber,
    required this.expectedDate,
    this.receivedDate,
    this.status = 'pending',
    required this.totalCost,
    this.additionalCosts = 0.0,
    this.responsibleEmployee,
    this.items = const [],
  });

  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity.toInt());

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    final itemsList = JsonHelpers.toList(json['items'])
        .map((e) => ShipmentItemModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return ShipmentModel(
      id: JsonHelpers.toStr(json['id']),
      supplierId: JsonHelpers.toStr(json['supplierId'] ?? json['supplier_id']),
      supplierName: JsonHelpers.extractString(
        json['supplier'],
        preferredKeys: ['name', 'fullName'],
        fallback: JsonHelpers.toStr(json['supplierName'], 'Поставщик'),
      ),
      invoiceNumber: JsonHelpers.toStr(json['invoiceNumber'] ?? json['shipment_number'], 'б/н'),
      expectedDate: JsonHelpers.toDateTime(json['expectedDate'] ?? json['expected_date']),
      receivedDate: JsonHelpers.toOptionalDateTime(json['receivedDate'] ?? json['received_date']),
      status: JsonHelpers.toStr(json['status'], 'pending').toLowerCase(),
      totalCost: JsonHelpers.toDouble(json['totalCost'] ?? json['total_amount']),
      additionalCosts: JsonHelpers.toDouble(json['additionalCosts'] ?? json['additional_costs']),
      responsibleEmployee: JsonHelpers.extractOptionalString(
            json['employee'] ?? json['user'],
            preferredKeys: ['fullName', 'name'],
          ) ??
          JsonHelpers.extractOptionalString(json['responsibleEmployee']),
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'invoiceNumber': invoiceNumber,
      'expectedDate': expectedDate.toIso8601String(),
      'status': status,
      'totalCost': totalCost,
      'additionalCosts': additionalCosts,
      'responsibleEmployee': responsibleEmployee,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
