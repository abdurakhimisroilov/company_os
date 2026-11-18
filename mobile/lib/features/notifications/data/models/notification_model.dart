import '../../../../core/utils/json_helpers.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;

  /// Lower-cased server type: 'finance', 'task', 'deal', 'sale', 'shipment', 'system'.
  /// It also tells what kind of record [referenceId] points to.
  final String type;
  final bool isRead;
  final String? referenceId;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.referenceId,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: JsonHelpers.toStr(json['id']),
      title: JsonHelpers.toStr(json['title']),
      body: JsonHelpers.toStr(json['body'] ?? json['message']),
      type: JsonHelpers.toStr(json['type'], 'system').toLowerCase(),
      isRead: JsonHelpers.toBool(json['isRead'] ?? json['is_read']),
      referenceId: JsonHelpers.extractOptionalString(json['referenceId'] ?? json['reference_id']),
      createdAt: JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']).toLocal(),
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
      createdAt: createdAt,
    );
  }

  /// In-app location of the record this notification is about, when the app
  /// has a screen for it.
  String? get targetRoute {
    final ref = referenceId;
    switch (type) {
      case 'task':
        return ref == null ? '/tasks' : '/tasks/$ref';
      case 'deal':
        return ref == null ? '/deals' : '/deals/$ref';
      case 'sale':
        return ref == null ? '/sales' : '/sales/$ref';
      case 'shipment':
        return ref == null ? '/incoming-goods' : '/incoming-goods/$ref';
      case 'finance':
        // Transactions have no screen of their own; the finance list shows them.
        return '/finance';
      default:
        return null;
    }
  }
}
