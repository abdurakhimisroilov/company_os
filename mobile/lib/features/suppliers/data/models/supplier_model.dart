import '../../../../core/utils/json_helpers.dart';

class SupplierPurchaseHistoryModel {
  final String id;
  final String invoiceNumber;
  final double amount;
  final DateTime? date;
  final String status; // pending | received | cancelled

  const SupplierPurchaseHistoryModel({
    required this.id,
    required this.invoiceNumber,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory SupplierPurchaseHistoryModel.fromJson(Map<String, dynamic> json) {
    return SupplierPurchaseHistoryModel(
      id: JsonHelpers.toStr(json['id']),
      invoiceNumber: JsonHelpers.toStr(json['shipment_number'] ?? json['invoice_number'] ?? json['invoiceNumber']),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['total_amount'] ?? json['totalCost']),
      date: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['date'])?.toLocal(),
      status: JsonHelpers.toStr(json['status']).toLowerCase(),
    );
  }
}

class SupplierModel {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final double totalPurchases;
  final double payableBalance;
  final List<SupplierPurchaseHistoryModel> purchases;

  const SupplierModel({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    this.address = '',
    this.totalPurchases = 0.0,
    this.payableBalance = 0.0,
    this.purchases = const [],
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    final pList = JsonHelpers.toList(json['shipments'] ?? json['purchases'] ?? json['purchaseHistory'])
        .map((e) => SupplierPurchaseHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return SupplierModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      contactPerson: JsonHelpers.toStr(json['contact_person'] ?? json['contactPerson']),
      phone: JsonHelpers.toStr(json['phone']),
      email: JsonHelpers.toStr(json['email']),
      address: JsonHelpers.toStr(json['address']),
      totalPurchases: JsonHelpers.toDouble(json['totalPurchases'] ?? json['total_purchases'] ?? json['totalSales']),
      payableBalance: JsonHelpers.toDouble(json['balance'] ?? json['payableBalance'] ?? json['debt']),
      purchases: pList,
    );
  }
}
