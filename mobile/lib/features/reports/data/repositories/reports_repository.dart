import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/report_model.dart';

class ReportsRepository {
  final ApiClient apiClient;

  ReportsRepository({required this.apiClient});

  /// `period`: today | week | month | year.
  Future<ReportModel> getFinancialReport({String period = 'month'}) async {
    final response = await apiClient.get(
      ApiEndpoints.reportsFinancial,
      queryParameters: {'period': period},
    );
    final body = response.data;
    if (body is! Map) throw Exception('Сервер вернул некорректный ответ');
    return ReportModel.fromJson(JsonHelpers.toMap(body.containsKey('data') ? body['data'] : body));
  }
}
