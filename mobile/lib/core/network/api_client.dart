import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'api_endpoints.dart';

class ApiClient {
  late final Dio dio;
  late final Dio _refreshDio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<String?>? _refreshInFlight;
  String? _cachedAccessToken;
  bool _tokenLoaded = false;

  /// Called once when the server rejects the session and it cannot be refreshed.
  void Function()? onSessionExpired;

  ApiClient({String? baseUrl}) {
    final options = BaseOptions(
      baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      headers: {'Accept': 'application/json'},
    );
    dio = Dio(options);
    // Refresh runs on its own client so a failing refresh can never wait on the
    // interceptor that is waiting for it.
    _refreshDio = Dio(options.copyWith());
    dio.interceptors.add(_AuthInterceptor(this));
  }

  String get baseUrl => dio.options.baseUrl;

  void setBaseUrl(String url) {
    dio.options.baseUrl = url;
    _refreshDio.options.baseUrl = url;
  }

  /// Absolute URL for a server file reference such as `/uploads/abc.pdf`.
  String resolveFileUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConstants.serverOrigin}${url.startsWith('/') ? '' : '/'}$url';
  }

  Future<String?> getAccessToken() async {
    if (!_tokenLoaded) {
      _cachedAccessToken = await _storage.read(key: AppConstants.accessTokenKey);
      _tokenLoaded = true;
    }
    return _cachedAccessToken;
  }

  /// Token state without touching storage; valid after the first [getAccessToken].
  bool get hasSessionCached => _tokenLoaded && (_cachedAccessToken?.isNotEmpty ?? false);
  bool get sessionKnown => _tokenLoaded;

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _cachedAccessToken = accessToken;
    _tokenLoaded = true;
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _tokenLoaded = true;
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userDataKey);
  }

  /// Returns a fresh access token, or null when the session is definitely over.
  /// Throws on network trouble so a flaky connection does not sign the user out.
  Future<String?> refreshAuthToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await _refreshDio.post(ApiEndpoints.refresh, data: {'refreshToken': refreshToken});
      final data = response.data;
      final newAccess = data is Map ? data['accessToken'] as String? : null;
      final newRefresh = data is Map ? data['refreshToken'] as String? : null;
      if (newAccess == null || newAccess.isEmpty) return null;
      await saveTokens(accessToken: newAccess, refreshToken: newRefresh ?? refreshToken);
      return newAccess;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) return null;
      rethrow;
    }
  }

  Future<void> _expireSession() async {
    final hadSession = _cachedAccessToken != null;
    await clearTokens();
    if (hadSession) onSessionExpired?.call();
  }

  // HTTP Helpers
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) {
    return dio.post<T>(path,
        data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.put<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  /// Uploads one file as multipart field `file`. [onProgress] receives 0.0–1.0
  /// as bytes actually leave the device.
  Future<Map<String, dynamic>> uploadFile(
    String filePath, {
    String? customFileName,
    String path = ApiEndpoints.fileUpload,
    Map<String, dynamic>? fields,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final fileName = customFileName ?? filePath.split(RegExp(r'[\\/]')).last;
    final formData = FormData.fromMap({
      ...?fields,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await dio.post(
      path,
      data: formData,
      cancelToken: cancelToken,
      options: Options(sendTimeout: const Duration(minutes: 5), receiveTimeout: const Duration(minutes: 2)),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) onProgress(sent / total);
      },
    );
    if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
    throw Exception('Не удалось загрузить файл на сервер');
  }

  /// Downloads a server file to [savePath]. [onProgress] receives 0.0–1.0.
  Future<void> downloadFile(String url, String savePath, {void Function(double progress)? onProgress, CancelToken? cancelToken}) async {
    await dio.download(
      resolveFileUrl(url),
      savePath,
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
      onReceiveProgress: (received, total) {
        if (onProgress != null && total > 0) onProgress(received / total);
      },
    );
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  _AuthInterceptor(this._client);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _client.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final isAuthCall = request.path.contains('/auth/login') || request.path.contains('/auth/register');
    if (err.response?.statusCode != 401 || isAuthCall || request.extra['retried'] == true) {
      return handler.next(err);
    }

    String? newToken;
    try {
      newToken = await _client.refreshAuthToken();
    } catch (_) {
      return handler.next(err);
    }
    if (newToken == null) {
      await _client._expireSession();
      return handler.next(err);
    }

    try {
      request.headers['Authorization'] = 'Bearer $newToken';
      request.extra['retried'] = true;
      // A consumed multipart body cannot be replayed; the caller retries those.
      if (request.data is FormData) return handler.next(err);
      handler.resolve(await _client.dio.fetch(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
