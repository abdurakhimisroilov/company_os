import '../../../../core/utils/json_helpers.dart';

/// Russian label of a payment method code ('cash', 'bank', 'card').
String paymentMethodLabel(String method) {
  switch (method.toLowerCase()) {
    case 'card':
      return 'Карта';
    case 'bank':
      return 'Банк';
    default:
      return 'Наличные';
  }
}

class SaleItemModel {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double price;
  final double total;

  const SaleItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['product_id'] ?? json['productId']),
      productName: JsonHelpers.toStr(json['product_name'] ?? json['productName'], 'Товар удалён'),
      quantity: JsonHelpers.toDouble(json['quantity']),
      price: JsonHelpers.toDouble(json['unit_price'] ?? json['price']),
      total: JsonHelpers.toDouble(json['total_amount'] ?? json['totalPrice']),
    );
  }
}

class SalePaymentHistoryModel {
  final String id;
  final double amount;
  final String method; // 'cash', 'bank', 'card'
  final DateTime? date;

  const SalePaymentHistoryModel({
    required this.id,
    required this.amount,
    required this.method,
    this.date,
  });

  factory SalePaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return SalePaymentHistoryModel(
      id: JsonHelpers.toStr(json['id']),
      amount: JsonHelpers.toDouble(json['amount']),
      method: JsonHelpers.toStr(json['payment_method'] ?? json['method'], 'cash').toLowerCase(),
      date: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['payment_date'] ?? json['date']),
    );
  }
}

class SaleModel {
  final String id;
  final String saleNumber;
  final String? customerId;

  /// Null for a retail sale without a customer.
  final String? customerName;
  final DateTime? date;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final String paymentStatus; // 'paid', 'partial', 'unpaid'
  final String paymentMethod; // 'cash', 'bank', 'card'
  final String? managerName;
  final List<SaleItemModel> items;
  final List<SalePaymentHistoryModel> payments;

  const SaleModel({
    required this.id,
    this.saleNumber = '',
    this.customerId,
    this.customerName,
    this.date,
    this.subtotal = 0,
    this.discount = 0,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentStatus,
    this.paymentMethod = 'cash',
    this.managerName,
    this.items = const [],
    this.payments = const [],
  });

  double get debtAmount {
    final debt = totalAmount - paidAmount;
    return debt > 0 ? debt : 0;
  }

  String get customerLabel => customerName ?? 'Без клиента';

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final itemsList = JsonHelpers.toList(json['items'])
        .map((e) => SaleItemModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    final paymentsList = JsonHelpers.toList(json['payments'])
        .map((e) => SalePaymentHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return SaleModel(
      id: JsonHelpers.toStr(json['id']),
      saleNumber: JsonHelpers.toStr(json['sale_number'] ?? json['saleNumber']),
      customerId: JsonHelpers.extractOptionalString(json['customer_id'] ?? json['customerId']),
      customerName: JsonHelpers.extractOptionalString(json['customer_name'] ?? json['customerName']),
      date: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['sale_date']),
      subtotal: JsonHelpers.toDouble(json['subtotal']),
      discount: JsonHelpers.toDouble(json['discount']),
      totalAmount: JsonHelpers.toDouble(json['grand_total'] ?? json['totalAmount']),
      paidAmount: JsonHelpers.toDouble(json['paid_amount'] ?? json['paidAmount']),
      paymentStatus: JsonHelpers.toStr(json['payment_status'] ?? json['paymentStatus'], 'unpaid').toLowerCase(),
      paymentMethod: JsonHelpers.toStr(json['payment_method'] ?? json['paymentMethod'], 'cash').toLowerCase(),
      managerName: JsonHelpers.extractOptionalString(json['manager_name'] ?? json['managerName']),
      items: itemsList,
      payments: paymentsList,
    );
  }
}
