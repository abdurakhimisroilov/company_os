import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/company_model.dart';

class CompanyRepository {
  final ApiClient apiClient;

  CompanyRepository({required this.apiClient});

  Map<String, dynamic> _data(dynamic body) {
    final map = JsonHelpers.toMap(body);
    return map['data'] is Map ? JsonHelpers.toMap(map['data']) : map;
  }

  /// Organizations the signed-in user belongs to; the active one comes first.
  Future<List<CompanyModel>> getCompanies() async {
    final response = await apiClient.get(ApiEndpoints.companies);
    return JsonHelpers.toList(response.data).map((e) => CompanyModel.fromJson(JsonHelpers.toMap(e))).toList();
  }

  Future<CompanyModel> getCurrentCompany() async {
    final response = await apiClient.get(ApiEndpoints.currentCompany);
    final map = _data(response.data);
    if (JsonHelpers.toStr(map['id']).isEmpty) {
      throw Exception('Активная организация не выбрана');
    }
    return CompanyModel.fromJson(map);
  }

  /// Creates an organization; the server makes it the active one.
  Future<CompanyModel> createCompany(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.companies, data: data);
    return CompanyModel.fromJson(_data(response.data));
  }

  /// The choice is stored on the server, so it survives restarts and other devices.
  Future<CompanyModel> switchCompany(String companyId) async {
    final response = await apiClient.post(ApiEndpoints.switchCompany, data: {'companyId': companyId});
    return CompanyModel.fromJson(_data(response.data));
  }

  Future<CompanyModel> updateCompany(String companyId, Map<String, dynamic> data) async {
    final response = await apiClient.patch('${ApiEndpoints.companies}/$companyId', data: data);
    return CompanyModel.fromJson(_data(response.data));
  }

  /// Deletes the organization with all its data. Returns the id of the
  /// organization that is active afterwards.
  Future<String?> deleteCompany(String companyId) async {
    final response = await apiClient.delete('${ApiEndpoints.companies}/$companyId');
    final id = JsonHelpers.toStr(JsonHelpers.toMap(response.data)['currentCompanyId']);
    return id.isEmpty ? null : id;
  }
}
