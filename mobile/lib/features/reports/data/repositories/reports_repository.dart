import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/report_model.dart';

class ReportsRepository {
  final ApiClient apiClient;

  ReportsRepository({required this.apiClient});

  Future<ReportModel> getFinancialReport({String period = 'month', String? type}) async {
    final query = <String, dynamic>{'period': period};
    if (type != null && type.isNotEmpty) query['type'] = type;

    final response = await apiClient.get(
      ApiEndpoints.reportsFinancial,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return ReportModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить финансовый отчёт');
  }

  Future<String> exportPdf({String period = 'month'}) async {
    final response = await apiClient.get(
      ApiEndpoints.reportsExportPdf,
      queryParameters: {'period': period},
    );
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(response.data);
      return JsonHelpers.toStr(map['url'], 'report.pdf');
    }
    throw Exception('Ошибка при экспорте в PDF');
  }

  Future<String> exportExcel({String period = 'month'}) async {
    final response = await apiClient.get(
      ApiEndpoints.reportsExportExcel,
      queryParameters: {'period': period},
    );
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(response.data);
      return JsonHelpers.toStr(map['url'], 'report.xlsx');
    }
    throw Exception('Ошибка при экспорте в Excel');
  }
}
