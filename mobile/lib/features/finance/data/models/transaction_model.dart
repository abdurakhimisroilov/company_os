import '../../../../core/utils/json_helpers.dart';

class TransactionModel {
  final String id;
  final String accountId;
  final String? accountName;
  final String type; // 'income' | 'expense' | 'transfer'
  final double amount;
  final String description;
  final String category;
  final String? referenceType;
  final String? referenceId;
  final String? employeeId;
  final String? employeeName;
  final String? documentUrl;
  final String? documentName;
  final DateTime date;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.accountId,
    this.accountName,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    this.referenceType,
    this.referenceId,
    this.employeeId,
    this.employeeName,
    this.documentUrl,
    this.documentName,
    required this.date,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: JsonHelpers.toStr(json['id']),
      accountId: JsonHelpers.toStr(json['accountId'] ?? json['account_id']),
      accountName: JsonHelpers.extractOptionalString(
            json['account'],
            preferredKeys: ['name', 'title'],
          ) ??
          JsonHelpers.extractOptionalString(json['accountName'] ?? json['account_name']),
      type: JsonHelpers.toStr(json['type'], 'expense').toLowerCase(),
      amount: JsonHelpers.toDouble(json['amount']),
      description: JsonHelpers.toStr(json['description']),
      category: JsonHelpers.toStr(json['category'] ?? json['category_name'], 'Прочее'),
      referenceType: JsonHelpers.extractOptionalString(json['referenceType'] ?? json['reference_type']),
      referenceId: JsonHelpers.extractOptionalString(json['referenceId'] ?? json['reference_id']),
      employeeId: JsonHelpers.extractOptionalString(json['employeeId'] ?? json['created_by']),
      employeeName: JsonHelpers.extractOptionalString(
            json['employee'] ?? json['user'],
            preferredKeys: ['fullName', 'name'],
          ) ??
          JsonHelpers.extractOptionalString(json['employeeName'] ?? json['created_by_name']),
      documentUrl: JsonHelpers.extractOptionalString(json['documentUrl'] ?? json['document_url']),
      documentName: JsonHelpers.extractOptionalString(json['documentName'] ?? json['document_name']),
      date: JsonHelpers.toDateTime(json['date'] ?? json['transaction_date']),
      createdAt: JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AccountModel {
  final String id;
  final String name;
  final String type; // 'cash' | 'bank' | 'card'
  final double balance;
  final String currency;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'UZS',
    this.isActive = true,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      type: JsonHelpers.toStr(json['type'], 'cash').toLowerCase(),
      balance: JsonHelpers.toDouble(json['balance']),
      currency: JsonHelpers.toStr(json['currency'], 'UZS'),
      isActive: JsonHelpers.toBool(json['isActive'] ?? json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'isActive': isActive,
    };
  }
}

class DebtModel {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? supplierId;
  final String? supplierName;
  final String type; // 'receivable' | 'payable'
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final String status; // 'pending' | 'overdue' | 'paid'

  const DebtModel({
    required this.id,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.amount,
    this.paidAmount = 0.0,
    required this.dueDate,
    this.status = 'pending',
  });

  double get remainingAmount => amount - paidAmount;

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: JsonHelpers.toStr(json['id']),
      customerId: JsonHelpers.extractOptionalString(json['customerId'] ?? json['customer_id']),
      customerName: JsonHelpers.extractOptionalString(
            json['customer'],
            preferredKeys: ['name', 'fullName'],
          ) ??
          JsonHelpers.extractOptionalString(json['customerName'] ?? json['customer_name']),
      supplierId: JsonHelpers.extractOptionalString(json['supplierId'] ?? json['supplier_id']),
      supplierName: JsonHelpers.extractOptionalString(
            json['supplier'],
            preferredKeys: ['name', 'fullName'],
          ) ??
          JsonHelpers.extractOptionalString(json['supplierName'] ?? json['supplier_name']),
      type: JsonHelpers.toStr(json['type'], 'receivable').toLowerCase(),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['totalAmount'] ?? json['balance']),
      paidAmount: JsonHelpers.toDouble(json['paidAmount']),
      dueDate: JsonHelpers.toDateTime(json['dueDate'] ?? json['due_date']),
      status: JsonHelpers.toStr(json['status'], 'pending').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'type': type,
      'amount': amount,
      'paidAmount': paidAmount,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
    };
  }
}
