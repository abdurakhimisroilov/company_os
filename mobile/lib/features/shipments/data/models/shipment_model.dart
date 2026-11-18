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
    return ShipmentItemModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['product_id'] ?? json['productId']),
      productName: JsonHelpers.toStr(json['product_name'] ?? json['productName'], 'Товар удалён'),
      quantity: JsonHelpers.toDouble(json['quantity']),
      unitPrice: JsonHelpers.toDouble(json['purchase_price'] ?? json['unitPrice']),
      totalPrice: JsonHelpers.toDouble(json['total_amount'] ?? json['totalPrice']),
    );
  }
}

class ShipmentModel {
  final String id;
  final String? supplierId;

  /// Null when the shipment was saved without a supplier.
  final String? supplierName;
  final String invoiceNumber;
  final DateTime? expectedDate;
  final DateTime? receivedDate;

  /// 'pending' (ожидается), 'received' (принята на склад) or 'cancelled'.
  final String status;

  /// Sum of the items, without additional costs.
  final double totalCost;
  final double additionalCosts;
  final String? responsibleEmployee;

  /// Filled only by the detail request.
  final List<ShipmentItemModel> items;

  const ShipmentModel({
    required this.id,
    this.supplierId,
    this.supplierName,
    required this.invoiceNumber,
    this.expectedDate,
    this.receivedDate,
    this.status = 'pending',
    required this.totalCost,
    this.additionalCosts = 0.0,
    this.responsibleEmployee,
    this.items = const [],
  });

  bool get isReceived => status == 'received';
  bool get isPending => status == 'pending';
  double get grandTotal => totalCost + additionalCosts;
  String get supplierLabel => supplierName ?? 'Без поставщика';

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    final itemsList = JsonHelpers.toList(json['items'])
        .map((e) => ShipmentItemModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return ShipmentModel(
      id: JsonHelpers.toStr(json['id']),
      supplierId: JsonHelpers.extractOptionalString(json['supplier_id'] ?? json['supplierId']),
      supplierName: JsonHelpers.extractOptionalString(json['supplier_name'] ?? json['supplierName']),
      invoiceNumber: JsonHelpers.toStr(json['shipment_number'] ?? json['invoiceNumber']),
      expectedDate: JsonHelpers.toOptionalDateTime(json['expected_date'] ?? json['expectedDate']),
      receivedDate: JsonHelpers.toOptionalDateTime(json['received_date'] ?? json['receivedDate']),
      status: JsonHelpers.toStr(json['status'], 'pending').toLowerCase(),
      totalCost: JsonHelpers.toDouble(json['total_amount'] ?? json['totalCost']),
      additionalCosts: JsonHelpers.toDouble(json['additional_costs'] ?? json['additionalCosts']),
      responsibleEmployee: JsonHelpers.extractOptionalString(json['created_by_name'] ?? json['responsibleEmployee']),
      items: itemsList,
    );
  }
}
