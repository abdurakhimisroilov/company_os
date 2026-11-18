import '../../../../core/utils/json_helpers.dart';

class DealCommentModel {
  final String id;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  const DealCommentModel({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory DealCommentModel.fromJson(Map<String, dynamic> json) {
    return DealCommentModel(
      id: JsonHelpers.toStr(json['id']),
      authorName: JsonHelpers.toStr(json['authorName'] ?? json['author_name']),
      text: JsonHelpers.toStr(json['text'] ?? json['comment'] ?? json['content']),
      createdAt: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['createdAt'])?.toLocal(),
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
  final DateTime? createdAt;
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
    this.createdAt,
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

    // `customer` may arrive as a plain name or as an object; the server's own
    // field is `customer_name`.
    final customerName = JsonHelpers.extractOptionalString(json['customer'], preferredKeys: ['name', 'fullName']) ??
        JsonHelpers.toStr(json['customer_name'] ?? json['customerName']);
    final status = JsonHelpers.toStr(json['status'], 'lead').toLowerCase();

    return DealModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title']),
      customerId: JsonHelpers.toStr(json['customer_id'] ?? json['customerId']),
      customerName: customerName,
      amount: JsonHelpers.toDouble(json['amount']),
      status: statusKeys.contains(status) ? status : 'lead',
      expectedCloseDate: JsonHelpers.toOptionalDateTime(json['expected_close_date'] ?? json['expectedCloseDate'])?.toLocal(),
      description: JsonHelpers.extractOptionalString(json['description']),
      assignedEmployeeName: JsonHelpers.extractOptionalString(
        json['assigned_employee_name'] ?? json['assignedEmployeeName'] ?? json['assigned_to_name'],
      ),
      createdAt: JsonHelpers.toOptionalDateTime(json['created_at'] ?? json['createdAt'])?.toLocal(),
      comments: commentsList,
    );
  }

  DealModel copyWith({String? status, List<DealCommentModel>? comments}) {
    return DealModel(
      id: id,
      title: title,
      customerId: customerId,
      customerName: customerName,
      amount: amount,
      status: status ?? this.status,
      expectedCloseDate: expectedCloseDate,
      description: description,
      assignedEmployeeName: assignedEmployeeName,
      createdAt: createdAt,
      comments: comments ?? this.comments,
    );
  }
}
