import '../../../../core/utils/json_helpers.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'finance', 'inventory', 'task', 'system', 'chat'
  final bool isRead;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.referenceType,
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
      referenceType: JsonHelpers.extractOptionalString(json['referenceType'] ?? json['reference_type']),
      referenceId: JsonHelpers.extractOptionalString(json['referenceId'] ?? json['reference_id']),
      createdAt: JsonHelpers.toDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}
