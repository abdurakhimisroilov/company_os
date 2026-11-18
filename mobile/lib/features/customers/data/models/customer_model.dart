import '../../../../core/utils/json_helpers.dart';

class CustomerSaleHistoryModel {
  final String id;
  final String saleNumber;
  final double amount;
  final double paidAmount;
  final DateTime? date;
  final String status; // paid | partial | unpaid

  const CustomerSaleHistoryModel({
    required this.id,
    required this.saleNumber,
    required this.amount,
    required this.paidAmount,
    required this.date,
    required this.status,
  });

  factory CustomerSaleHistoryModel.fromJson(Map<String, dynamic> json) {
    return CustomerSaleHistoryModel(
      id: JsonHelpers.toStr(json['id']),
      saleNumber: JsonHelpers.toStr(json['sale_number'] ?? json['saleNumber']),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['total_amount'] ?? json['totalAmount'] ?? json['grand_total']),
      paidAmount: JsonHelpers.toDouble(json['paid_amount'] ?? json['paidAmount']),
      date: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['date'] ?? json['createdAt'])?.toLocal(),
      status: JsonHelpers.toStr(json['status']).toLowerCase(),
    );
  }
}

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String inn;
  final String notes;
  final double totalPurchases;
  final double debtAmount;
  final List<CustomerSaleHistoryModel> purchaseHistory;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.address = '',
    this.inn = '',
    this.notes = '',
    this.totalPurchases = 0.0,
    this.debtAmount = 0.0,
    this.purchaseHistory = const [],
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final historyList = JsonHelpers.toList(json['sales'] ?? json['purchaseHistory'])
        .map((e) => CustomerSaleHistoryModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return CustomerModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      phone: JsonHelpers.toStr(json['phone']),
      email: JsonHelpers.toStr(json['email']),
      address: JsonHelpers.toStr(json['address']),
      inn: JsonHelpers.toStr(json['inn']),
      notes: JsonHelpers.toStr(json['notes']),
      totalPurchases: JsonHelpers.toDouble(json['totalPurchases'] ?? json['total_purchases'] ?? json['totalSales']),
      debtAmount: JsonHelpers.toDouble(json['balance'] ?? json['debtAmount'] ?? json['debt']),
      purchaseHistory: historyList,
    );
  }
}
