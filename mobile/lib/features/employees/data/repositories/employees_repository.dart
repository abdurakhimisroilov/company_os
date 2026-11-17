import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/employee_model.dart';

class EmployeesRepository {
  final ApiClient apiClient;

  EmployeesRepository({required this.apiClient});

  Future<List<EmployeeModel>> getEmployees({
    String? departmentId,
    String? role,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) {
      query['departmentId'] = departmentId;
    }
    if (role != null && role.isNotEmpty && role != 'all') {
      query['role'] = role;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    final response = await apiClient.get(
      ApiEndpoints.employees,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      final list = JsonHelpers.toList(response.data);
      return list.map((e) => EmployeeModel.fromJson(JsonHelpers.toMap(e))).toList();
    }
    throw Exception('Не удалось загрузить сотрудников');
  }

  Future<EmployeeModel> getEmployeeById(String id) async {
    final response = await apiClient.get(ApiEndpoints.employee(id));
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return EmployeeModel.fromJson(map);
    }
    throw Exception('Не удалось загрузить данные сотрудника');
  }

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) async {
    final response = await apiClient.post(ApiEndpoints.employees, data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return EmployeeModel.fromJson(map);
    }
    throw Exception('Не удалось создать сотрудника');
  }

  Future<List<String>> getDepartments() async {
    try {
      final response = await apiClient.get('/departments');
      if (response.statusCode == 200) {
        final list = JsonHelpers.toList(response.data);
        final result = list.map((e) {
          if (e is Map && e.containsKey('name')) return e['name'].toString();
          return e.toString();
        }).toList();
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return ['Руководство', 'IT', 'Продажи', 'Финансы', 'Склад', 'HR'];
  }

  Future<EmployeeModel> updateEmployee(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patch('${ApiEndpoints.employees}/$id', data: data);
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return EmployeeModel.fromJson(map);
    }
    throw Exception('Не удалось обновить сотрудника');
  }

  Future<EmployeeModel> updateEmployeeRole(String id, String role) async {
    final response = await apiClient.patch(
      '${ApiEndpoints.employees}/$id/role',
      data: {'role': role},
    );
    if (response.statusCode == 200) {
      final map = JsonHelpers.toMap(
        response.data is Map && (response.data as Map).containsKey('data')
            ? (response.data as Map)['data']
            : response.data,
      );
      return EmployeeModel.fromJson(map);
    }
    throw Exception('Не удалось изменить роль сотрудника');
  }
}
