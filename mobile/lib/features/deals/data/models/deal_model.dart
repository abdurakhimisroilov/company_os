import '../../../../core/utils/json_helpers.dart';

class DealCommentModel {
  final String id;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const DealCommentModel({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory DealCommentModel.fromJson(Map<String, dynamic> json) {
    return DealCommentModel(
      id: JsonHelpers.toStr(json['id']),
      authorName: JsonHelpers.extractString(
        json['author'],
        preferredKeys: ['fullName', 'name'],
        fallback: JsonHelpers.toStr(json['authorName'], 'Сотрудник'),
      ),
      text: JsonHelpers.toStr(json['text'] ?? json['content']),
      createdAt: JsonHelpers.toDateTime(json['createdAt']),
    );
  }
}

class DealModel {
  final String id;
  final String title;
  final String customerId;
  final String customerName;
  final double amount;
  final String status; // 'lead', 'contact', 'negotiation', 'proposal', 'waiting_payment', 'won', 'lost'
  final DateTime? expectedCloseDate;
  final String? description;
  final String? assignedEmployeeName;
  final List<DealCommentModel> comments;

  const DealModel({
    required this.id,
    required this.title,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.status,
    this.expectedCloseDate,
    this.description,
    this.assignedEmployeeName,
    this.comments = const [],
  });

  static const List<String> statusKeys = [
    'lead',
    'contact',
    'negotiation',
    'proposal',
    'waiting_payment',
    'won',
    'lost',
  ];

  static const Map<String, String> statusNames = {
    'lead': 'Новый',
    'contact': 'Контакт',
    'negotiation': 'Переговоры',
    'proposal': 'КП отправлено',
    'waiting_payment': 'Ожидание оплаты',
    'won': 'Успешно',
    'lost': 'Потерян',
  };

  String get statusDisplay => statusNames[status] ?? status;

  factory DealModel.fromJson(Map<String, dynamic> json) {
    final commentsList = JsonHelpers.toList(json['comments'])
        .map((e) => DealCommentModel.fromJson(JsonHelpers.toMap(e)))
        .toList();

    return DealModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title'] ?? json['name'], 'Сделка'),
      customerId: JsonHelpers.toStr(json['customerId'] ?? json['customer_id']),
      customerName: JsonHelpers.extractString(
        json['customer'],
        preferredKeys: ['name', 'fullName'],
        fallback: JsonHelpers.toStr(json['customerName'], 'Клиент'),
      ),
      amount: JsonHelpers.toDouble(json['amount'] ?? json['value']),
      status: JsonHelpers.toStr(json['status'], 'lead').toLowerCase(),
      expectedCloseDate: JsonHelpers.toOptionalDateTime(json['expectedCloseDate'] ?? json['close_date']),
      description: JsonHelpers.extractOptionalString(json['description']),
      assignedEmployeeName: JsonHelpers.extractOptionalString(
            json['assignedTo'] ?? json['employee'],
            preferredKeys: ['fullName', 'name'],
          ) ??
          JsonHelpers.extractOptionalString(json['assignedEmployeeName']),
      comments: commentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'customerId': customerId,
      'customerName': customerName,
      'amount': amount,
      'status': status,
      'expectedCloseDate': expectedCloseDate?.toIso8601String(),
      'description': description,
    };
  }
}
