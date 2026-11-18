import '../../../../core/utils/json_helpers.dart';

/// The operation day is a calendar date ('YYYY-MM-DD'). Older servers sent it as
/// local midnight in UTC; rounding to the nearest UTC midnight recovers the day.
DateTime? _calendarDay(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString();
  final plain = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (plain != null) {
    return DateTime(int.parse(plain.group(1)!), int.parse(plain.group(2)!), int.parse(plain.group(3)!));
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  if (!parsed.isUtc) return DateTime(parsed.year, parsed.month, parsed.day);
  final rounded = parsed.add(const Duration(hours: 12));
  return DateTime(rounded.year, rounded.month, rounded.day);
}

class TransactionModel {
  final String id;
  final String accountId;
  final String? accountName;
  final String type; // 'income' | 'expense' | 'transfer_in' | 'transfer_out'
  final double amount;
  final String description;
  final String category;
  final String? paymentMethod; // 'cash' | 'bank' | 'card'
  final String? counterparty;
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
    this.paymentMethod,
    this.counterparty,
    this.referenceType,
    this.referenceId,
    this.employeeId,
    this.employeeName,
    this.documentUrl,
    this.documentName,
    required this.date,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isTransfer => type.startsWith('transfer');
  bool get isTransferIn => type == 'transfer_in';

  /// Money arrives on the account (income or the receiving side of a transfer).
  bool get isInflow => isIncome || isTransferIn;

  String? get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'Наличные';
      case 'bank':
        return 'Банковский перевод';
      case 'card':
        return 'Карта';
      default:
        return null;
    }
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final createdAt = JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']).toLocal();
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
      paymentMethod: JsonHelpers.extractOptionalString(json['paymentMethod'] ?? json['payment_method'])?.toLowerCase(),
      counterparty: JsonHelpers.extractOptionalString(
        json['counterpartyName'] ?? json['counterparty_name'] ?? json['customerName'],
      ),
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
      date: _calendarDay(json['transactionDate'] ?? json['transaction_date']) ??
          JsonHelpers.toOptionalDateTime(json['date'])?.toLocal() ??
          createdAt,
      createdAt: createdAt,
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
      'paymentMethod': paymentMethod,
      'counterpartyName': counterparty,
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

/// One page of the transaction list together with the server-side total.
class TransactionPage {
  final List<TransactionModel> items;
  final int total;
  const TransactionPage({required this.items, required this.total});
}

class AccountModel {
  final String id;
  final String name;
  final String type; // 'cash' | 'bank' | 'card'
  final double balance;
  final String currency;
  final String? accountNumber;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'UZS',
    this.accountNumber,
    this.isActive = true,
  });

  String get typeLabel => type == 'cash' ? 'Наличная касса' : (type == 'card' ? 'Корпоративная карта' : 'Расчётный счёт');

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      type: JsonHelpers.toStr(json['type'], 'cash').toLowerCase(),
      balance: JsonHelpers.toDouble(json['balance']),
      currency: JsonHelpers.toStr(json['currency'], 'UZS'),
      accountNumber: JsonHelpers.extractOptionalString(json['accountNumber'] ?? json['account_number']),
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
      'accountNumber': accountNumber,
      'isActive': isActive,
    };
  }
}

/// A customer or supplier that can be picked as the counterparty of an operation.
class PartyRef {
  final String id;
  final String name;
  final String phone;
  final double balance;

  const PartyRef({required this.id, required this.name, this.phone = '', this.balance = 0});

  factory PartyRef.fromJson(Map<String, dynamic> json) {
    return PartyRef(
      id: JsonHelpers.toStr(json['id']),
      name: JsonHelpers.toStr(json['name']),
      phone: JsonHelpers.toStr(json['phone']),
      balance: JsonHelpers.toDouble(json['balance']),
    );
  }
}

class DebtModel {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? supplierId;
  final String? supplierName;
  final String type; // 'receivable' | 'payable'

  /// What is still owed right now (the counterparty's current balance).
  final double amount;

  /// What has already been paid towards this debt.
  final double paidAmount;

  /// The server keeps no payment deadline for a debt, so this is normally null.
  final DateTime? dueDate;
  final String status;

  const DebtModel({
    required this.id,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.amount,
    this.paidAmount = 0.0,
    this.dueDate,
    this.status = 'pending',
  });

  double get remainingAmount => amount;

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
      paidAmount: JsonHelpers.toDouble(json['paidAmount'] ?? json['paid_amount']),
      dueDate: JsonHelpers.toOptionalDateTime(json['dueDate'] ?? json['due_date']),
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
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
    };
  }
}
