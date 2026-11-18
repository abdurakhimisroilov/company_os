import 'package:dio/dio.dart';

/// Text to show the user for any failure coming out of a repository call.
String apiErrorMessage(Object error, {String fallback = 'Произошла ошибка. Попробуйте ещё раз'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null && data['message'].toString().trim().isNotEmpty) {
      return data['message'].toString();
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Проверьте подключение к интернету';
      case DioExceptionType.connectionError:
        return 'Нет подключения к серверу';
      case DioExceptionType.cancel:
        return 'Запрос отменён';
      default:
        break;
    }
    final status = error.response?.statusCode;
    if (status == 401) return 'Сессия истекла. Войдите снова';
    if (status == 403) return 'Недостаточно прав для этого действия';
    if (status == 404) return 'Данные не найдены';
    if (status != null && status >= 500) return 'Ошибка сервера. Попробуйте позже';
    return fallback;
  }
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? fallback : text;
}
