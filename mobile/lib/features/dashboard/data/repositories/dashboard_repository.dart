import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/dashboard_stats_model.dart';

class DashboardRepository {
  final ApiClient apiClient;

  DashboardRepository({required this.apiClient});

  Future<DashboardStatsModel> fetchDashboardStats({String period = 'month'}) => getStats(period: period);

  /// `period`: today | week | month | year. Throws when the server cannot be
  /// reached or answers with an error, so the screen never shows invented numbers.
  Future<DashboardStatsModel> getStats({String period = 'month'}) async {
    final response = await apiClient.get(
      ApiEndpoints.dashboardStats,
      queryParameters: {'period': period},
    );
    final body = response.data;
    if (body is! Map) throw Exception('Сервер вернул некорректный ответ');
    final map = JsonHelpers.toMap(body.containsKey('data') ? body['data'] : body);
    return DashboardStatsModel.fromJson(map);
  }
}
