import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/notification_model.dart';

/// Notifications of the signed-in user. Every call throws on failure so the
/// caller can tell the user and put the list back.
class NotificationsRepository {
  final ApiClient apiClient;

  NotificationsRepository({required this.apiClient});

  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await apiClient.get(ApiEndpoints.notifications);
    return JsonHelpers.toList(response.data).map((e) => AppNotificationModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<void> markAllAsRead() async {
    await apiClient.post(ApiEndpoints.notificationsMarkAllRead);
  }

  Future<void> markAsRead(String id) async {
    await apiClient.patch('${ApiEndpoints.notifications}/$id/read');
  }

  Future<void> deleteNotification(String id) async {
    await apiClient.delete('${ApiEndpoints.notifications}/$id');
  }
}
