import '../../../../core/utils/json_helpers.dart';

class CustomerSaleHistoryModel {
  final String id;
  final double amount;
  final double paidAmount;
  final DateTime date;
  final String status;

  const CustomerSaleHistoryModel({
    required this.id,
    required this.amount,
    required this.paidAmount,
    required this.date,
    required this.status,
  });

  factory CustomerSaleHistoryModel.fromJson(Map<String, dynamic> json) {
    return CustomerSaleHistoryModel(
      id: JsonHelpers.toStr(json['id']),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['totalAmount']),
      paidAmount: JsonHelpers.toDouble(json['paidAmount']),
      date: JsonHelpers.toDateTime(json['date'] ?? json['createdAt']),
      status: JsonHelpers.toStr(json['status'], 'paid'),
    );
  }
}

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final double totalPurchases;
  final double debtAmount;
  final List<CustomerSaleHistoryModel> purchaseHistory;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.address = '',
    this.totalPurchases = 0.0,
    this.debtAmount = 0.0,
    this.purchaseHistory = const [],
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final historyList = JsonHelpers.toList(json['purchaseHistory'] ?? json['sales'])
        .map((e) => CustomerSaleHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return CustomerModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.extractString(json['name'], fallback: 'Без имени'),
      phone: JsonHelpers.toStr(json['phone']),
      email: JsonHelpers.toStr(json['email']),
      address: JsonHelpers.toStr(json['address']),
      totalPurchases: JsonHelpers.toDouble(json['totalPurchases'] ?? json['totalSales']),
      debtAmount: JsonHelpers.toDouble(json['debtAmount'] ?? json['debt'] ?? json['balance']),
      purchaseHistory: historyList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }
}
