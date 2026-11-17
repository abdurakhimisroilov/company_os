import '../../../../core/utils/json_helpers.dart';

class SupplierPurchaseHistoryModel {
  final String id;
  final String invoiceNumber;
  final double amount;
  final DateTime date;
  final String status;

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
      invoiceNumber: JsonHelpers.toStr(json['invoiceNumber'] ?? json['shipment_number'], 'б/н'),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['totalCost'] ?? json['total_amount']),
      date: JsonHelpers.toDateTime(json['date'] ?? json['created_at']),
      status: JsonHelpers.toStr(json['status'], 'received'),
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
    final pList = JsonHelpers.toList(json['purchases'] ?? json['shipments'])
        .map((e) => SupplierPurchaseHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return SupplierModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name'], 'Поставщик'),
      contactPerson: JsonHelpers.extractString(
        json['contactPerson'] ?? json['contact'],
        preferredKeys: ['name', 'fullName'],
        fallback: '',
      ),
      phone: JsonHelpers.toStr(json['phone']),
      email: JsonHelpers.toStr(json['email']),
      address: JsonHelpers.toStr(json['address']),
      totalPurchases: JsonHelpers.toDouble(json['totalPurchases'] ?? json['total_purchases']),
      payableBalance: JsonHelpers.toDouble(json['payableBalance'] ?? json['debt'] ?? json['balance']),
      purchases: pList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}
