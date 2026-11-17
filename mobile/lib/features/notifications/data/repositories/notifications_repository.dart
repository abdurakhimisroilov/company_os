import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final ApiClient apiClient;

  NotificationsRepository({required this.apiClient});

  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await apiClient.get(ApiEndpoints.notifications);
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => AppNotificationModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить уведомления');
  }

  Future<void> markAllAsRead() async {
    try {
      await apiClient.post(ApiEndpoints.notificationsMarkAllRead);
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await apiClient.patch('${ApiEndpoints.notifications}/$id/read');
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await apiClient.delete('${ApiEndpoints.notifications}/$id');
    } catch (_) {}
  }
}
