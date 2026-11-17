import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/dashboard_stats_model.dart';

class DashboardRepository {
  final ApiClient apiClient;

  DashboardRepository({required this.apiClient});

  Future<DashboardStatsModel> fetchDashboardStats({String period = 'month'}) => getStats(period: period);

  Future<DashboardStatsModel> getStats({String period = 'month'}) async {
    try {
      final response = await apiClient.get(
        ApiEndpoints.dashboardStats,
        queryParameters: {'period': period},
      );

      if (response.statusCode == 200) {
        final map = JsonHelpers.toMap(
          response.data is Map && (response.data as Map).containsKey('data')
              ? (response.data as Map)['data']
              : response.data,
        );
        return DashboardStatsModel.fromJson(map);
      }
    } catch (e) {
      // Return empty non-fabricated initial state if server is momentarily unreachable
      return DashboardStatsModel(
        totalBalance: 0.0,
        balanceChangePercent: 0.0,
        income: 0.0,
        expenses: 0.0,
        sales: 0.0,
        stockBalance: 0.0,
        totalProducts: 0,
        activeDeals: 0,
        pendingTasks: 0,
        customerDebts: 0.0,
        supplierDebts: 0.0,
        period: period,
      );
    }

    return DashboardStatsModel(
      totalBalance: 0.0,
      balanceChangePercent: 0.0,
      income: 0.0,
      expenses: 0.0,
      sales: 0.0,
      stockBalance: 0.0,
      totalProducts: 0,
      activeDeals: 0,
      pendingTasks: 0,
      customerDebts: 0.0,
      supplierDebts: 0.0,
      period: period,
    );
  }
}
