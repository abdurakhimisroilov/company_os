import '../../../../core/utils/json_helpers.dart';

class SaleItemModel {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double price;
  final double discount;
  final double total;

  const SaleItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    required this.total,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: JsonHelpers.toStr(json['id']),
      productId: JsonHelpers.toStr(json['productId'] ?? json['product_id']),
      productName: JsonHelpers.extractString(
        json['product'],
        preferredKeys: ['name', 'title'],
        fallback: JsonHelpers.toStr(json['productName'], 'Товар'),
      ),
      quantity: JsonHelpers.toDouble(json['quantity']),
      price: JsonHelpers.toDouble(json['price'] ?? json['unitPrice'] ?? json['unit_price']),
      discount: JsonHelpers.toDouble(json['discount']),
      total: JsonHelpers.toDouble(json['total'] ?? json['totalPrice'] ?? json['total_amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'total': total,
    };
  }
}

class SalePaymentHistoryModel {
  final String id;
  final double amount;
  final String method; // 'cash', 'bank', 'card'
  final DateTime date;

  const SalePaymentHistoryModel({
    required this.id,
    required this.amount,
    required this.method,
    required this.date,
  });

  factory SalePaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return SalePaymentHistoryModel(
      id: JsonHelpers.toStr(json['id']),
      amount: JsonHelpers.toDouble(json['amount']),
      method: JsonHelpers.toStr(json['method'] ?? json['payment_method'], 'cash'),
      date: JsonHelpers.toDateTime(json['date'] ?? json['payment_date'] ?? json['createdAt']),
    );
  }
}

class SaleModel {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final double paidAmount;
  final String paymentStatus; // 'paid', 'partial', 'unpaid'
  final String paymentMethod; // 'cash', 'bank', 'card'
  final String? managerName;
  final List<SaleItemModel> items;
  final List<SalePaymentHistoryModel> payments;

  const SaleModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentStatus,
    this.paymentMethod = 'cash',
    this.managerName,
    this.items = const [],
    this.payments = const [],
  });

  double get debtAmount => totalAmount - paidAmount;

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final itemsList = JsonHelpers.toList(json['items'])
        .map((e) => SaleItemModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    final paymentsList = JsonHelpers.toList(json['payments'])
        .map((e) => SalePaymentHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return SaleModel(
      id: JsonHelpers.toStr(json['id']),
      customerId: JsonHelpers.toStr(json['customerId'] ?? json['customer_id']),
      customerName: JsonHelpers.extractString(
        json['customer'],
        preferredKeys: ['name', 'fullName'],
        fallback: JsonHelpers.toStr(json['customerName'], 'Клиент'),
      ),
      date: JsonHelpers.toDateTime(json['date'] ?? json['created_at']),
      totalAmount: JsonHelpers.toDouble(json['totalAmount'] ?? json['grand_total'] ?? json['amount']),
      paidAmount: JsonHelpers.toDouble(json['paidAmount'] ?? json['paid_amount']),
      paymentStatus: JsonHelpers.toStr(json['paymentStatus'] ?? json['payment_status'] ?? json['status'], 'unpaid').toLowerCase(),
      paymentMethod: JsonHelpers.toStr(json['paymentMethod'] ?? json['payment_method'], 'cash'),
      managerName: JsonHelpers.extractOptionalString(
            json['employee'] ?? json['user'],
            preferredKeys: ['fullName', 'name'],
          ) ??
          JsonHelpers.extractOptionalString(json['managerName']),
      items: itemsList,
      payments: paymentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'items': items.map((e) => e.toJson()).toList(),
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
    };
  }
}
