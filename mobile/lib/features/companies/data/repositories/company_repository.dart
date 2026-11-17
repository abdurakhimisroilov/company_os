import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/company_model.dart';

class CompanyRepository {
  final ApiClient apiClient;

  CompanyRepository({required this.apiClient});

  Future<List<CompanyModel>> getCompanies() async {
    final response = await apiClient.get(ApiEndpoints.companies);
    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => CompanyModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить список организаций');
  }

  Future<CompanyModel> getCurrentCompany() async {
    final response = await apiClient.get(ApiEndpoints.currentCompany);
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return CompanyModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить текущую организацию');
  }

  Future<CompanyModel> createCompany(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.companies, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return CompanyModel.fromJson(map);
    }
    throw Exception('Не удалось создать организацию');
  }

  Future<CompanyModel> switchCompany(String companyId) async {
    final response = await apiClient.post(ApiEndpoints.switchCompany, data: {'companyId': companyId});
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return CompanyModel.fromJson(map);
    }
    throw Exception('Не удалось переключить организацию');
  }
}
