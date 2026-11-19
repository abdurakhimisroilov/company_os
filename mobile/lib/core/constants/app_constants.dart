class AppConstants {
  AppConstants._();

  // ─── API ───────────────────────────────────────────────────────────────────
  // Override per build: --dart-define=API_BASE_URL=https://api.example.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://45.158.199.215:3000/api/v1',
  );

  /// Scheme + host + port of the API, used to resolve relative `/uploads/...` links.
  static String get serverOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }

  static String get defaultHost => Uri.parse(apiBaseUrl).authority;
  static String get wsBaseUrl => serverOrigin.replaceFirst('http', 'ws');
  static const String apiVersion = 'v1';

  // ─── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ─── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int chatPageSize = 50;

  // ─── Token storage keys ────────────────────────────────────────────────────
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // ─── PIN & Biometrics storage keys ─────────────────────────────────────────
  static const String pinHashKey = 'user_pin_hash';
  static const String pinSaltKey = 'user_pin_salt';
  static const String biometricEnabledKey = 'user_biometric_enabled';
  static const String pinFailedAttemptsKey = 'user_pin_failed_attempts';
  static const String pinLockoutUntilKey = 'user_pin_lockout_until';

  // ─── Hive boxes ────────────────────────────────────────────────────────────
  static const String settingsBox = 'settings_box';
  static const String userBox = 'user_box';
  static const String cacheBox = 'cache_box';

  // ─── Date formats ──────────────────────────────────────────────────────────
  static const String dateFormat = 'dd.MM.yyyy';
  static const String dateTimeFormat = 'dd.MM.yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  static const String monthYearFormat = 'MMMM yyyy';
  static const String isoDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";

  // ─── Currency ──────────────────────────────────────────────────────────────
  static const String currencySuffix = ' сум';
  static const String currencyCode = 'UZS';

  // ─── File sizes ────────────────────────────────────────────────────────────
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB

  // ─── Misc ──────────────────────────────────────────────────────────────────
  static const int debounceMs = 400;
  static const String appName = 'OPERO';
  static const String companyName = 'Opero';
  static const String packageName = 'com.companyos.app';
}
