import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_helpers.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepository({required this.apiClient});

  Future<UserModel> _storeSession(dynamic responseData) async {
    final data = JsonHelpers.toMap(responseData);
    final accessToken = JsonHelpers.toStr(data['accessToken']);
    final refreshToken = JsonHelpers.toStr(data['refreshToken']);
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw Exception('Сервер вернул некорректный ответ. Попробуйте ещё раз');
    }
    await apiClient.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    return _cacheUser(JsonHelpers.toMap(data['user']));
  }

  Future<UserModel> _cacheUser(Map<String, dynamic> userJson) async {
    await _storage.write(key: AppConstants.userDataKey, value: jsonEncode(userJson));
    return UserModel.fromJson(userJson);
  }

  Future<UserModel> login({required String email, required String password}) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {'email': email.trim(), 'password': password},
    );
    return _storeSession(response.data);
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? companyName,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.register,
      data: {
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (companyName != null && companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
      },
    );
    return _storeSession(response.data);
  }

  /// Ends the session on this device first, then tells the server.
  Future<void> logout() async {
    final token = await apiClient.getAccessToken();
    await apiClient.clearTokens();
    if (token != null && token.isNotEmpty) {
      try {
        await apiClient.dio.post(
          ApiEndpoints.logout,
          options: Options(headers: {'Authorization': 'Bearer $token'}, sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
        );
      } catch (_) {}
    }
  }

  Future<UserModel?> getCachedUser() async {
    try {
      final userString = await _storage.read(key: AppConstants.userDataKey);
      if (userString == null || userString.isEmpty) return null;
      return UserModel.fromJson(JsonHelpers.toMap(jsonDecode(userString)));
    } catch (_) {
      return null;
    }
  }

  /// Profile as the server has it now; also proves the session is still valid.
  Future<UserModel> fetchCurrentUser() async {
    final response = await apiClient.get(ApiEndpoints.me);
    return _cacheUser(JsonHelpers.toMap(response.data));
  }

  Future<UserModel> updateProfile(Map<String, dynamic> fields) async {
    final response = await apiClient.patch('/auth/profile', data: fields);
    return _cacheUser(JsonHelpers.toMap(response.data));
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final response = await apiClient.post(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    final data = JsonHelpers.toMap(response.data);
    final accessToken = JsonHelpers.toStr(data['accessToken']);
    final refreshToken = JsonHelpers.toStr(data['refreshToken']);
    if (accessToken.isNotEmpty && refreshToken.isNotEmpty) {
      await apiClient.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    }
  }

  /// Permanently deletes the account on the server, then clears this device.
  Future<void> deleteAccount({required String password}) async {
    await apiClient.delete('/auth/account', data: {'password': password});
    await apiClient.clearTokens();
  }

  Future<bool> isAuthenticated() async {
    final token = await apiClient.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
