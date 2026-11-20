import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';

/// Notifications outside the app, without Firebase.
///
/// iPhone: real push. The app registers its APNs token with the server, which
/// sends alerts straight to Apple (see backend/apns.js).
/// Android: there is no push channel without Firebase, so a background task
/// asks the server for new notifications about every 15 minutes (the shortest
/// interval Android allows) and shows them as local notifications.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const MethodChannel _ios = MethodChannel('opero/push');
  static const String prefsEnabled = 'push_enabled';
  static const String prefsDeviceToken = 'push_device_token';
  static const String _androidTask = 'opero-notification-check';

  /// Fires when an iPhone push arrives while the app is open (refresh the list).
  final ValueNotifier<int> received = ValueNotifier<int>(0);

  /// Fires when the user taps a notification (open the notifications screen).
  final ValueNotifier<int> opened = ValueNotifier<int>(0);

  bool _handlersSet = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isEnabledLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsEnabled) ?? true;
  }

  /// Turns notifications on for this phone and the signed-in user. Asks the
  /// system for permission the first time. Returns false if it was refused.
  Future<bool> enable(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabled, true);
    // Screen-recording runs (integration tests) skip the system permission prompt.
    if (const bool.fromEnvironment('SKIP_PUSH_PROMPT')) return false;
    if (_isIOS) return _enableIOS(api, prefs);
    if (_isAndroid) return _enableAndroid(prefs);
    return false;
  }

  /// Turns notifications off for this phone.
  Future<void> disable(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabled, false);
    await unregister(api);
  }

  /// Removes this phone from the account (sign-out, notifications off).
  Future<void> unregister(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(prefsDeviceToken);
    if (token != null) {
      try {
        await api.delete('/devices', data: {'token': token});
      } catch (_) {}
      await prefs.remove(prefsDeviceToken);
    }
    if (_isAndroid) {
      try {
        await Workmanager().cancelByUniqueName(_androidTask);
      } catch (_) {}
    }
    if (_isIOS) {
      try {
        await _ios.invokeMethod('setBadge', 0);
      } catch (_) {}
    }
  }

  /// Keeps the app icon badge equal to the unread count (iPhone).
  Future<void> setBadge(int unread) async {
    if (!_isIOS) return;
    try {
      await _ios.invokeMethod('setBadge', unread < 0 ? 0 : unread);
    } catch (_) {}
  }

  void _listenIOS() {
    if (_handlersSet) return;
    _handlersSet = true;
    _ios.setMethodCallHandler((call) async {
      if (call.method == 'onPush') received.value++;
      if (call.method == 'onTap') opened.value++;
    });
  }

  Future<bool> _enableIOS(ApiClient api, SharedPreferences prefs) async {
    _listenIOS();
    String? token;
    try {
      token = await _ios.invokeMethod<String>('requestToken');
    } on PlatformException catch (e) {
      debugPrint('[PushService] APNs registration failed: ${e.message}');
      return false;
    }
    if (token == null || token.isEmpty) return false;
    await api.post('/devices', data: {
      'token': token,
      'platform': 'ios',
      // Debug builds get sandbox tokens; TestFlight and App Store builds get production ones.
      'environment': kReleaseMode ? 'production' : 'sandbox',
    });
    await prefs.setString(prefsDeviceToken, token);
    return true;
  }

  Future<bool> _enableAndroid(SharedPreferences prefs) async {
    final plugin = await _localNotifications();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? true;
    if (!granted) return false;
    // Only notifications created from now on are shown by the background check.
    prefs.setString(_prefsLastCheck, DateTime.now().toUtc().toIso8601String());
    await Workmanager().initialize(pushBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _androidTask,
      _androidTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    return true;
  }
}

const String _prefsLastCheck = 'push_last_check';
const String _androidChannelId = 'opero_updates';

FlutterLocalNotificationsPlugin? _plugin;

Future<FlutterLocalNotificationsPlugin> _localNotifications() async {
  final existing = _plugin;
  if (existing != null) return existing;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (_) => PushService.instance.opened.value++,
  );
  _plugin = plugin;
  return plugin;
}

/// Android background check: runs in its own isolate, so it reads the session
/// straight from storage and talks to the server with a plain Dio client.
@pragma('vm:entry-point')
void pushBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(PushService.prefsEnabled) == false) return true;
      const storage = FlutterSecureStorage();
      var access = await storage.read(key: AppConstants.accessTokenKey);
      if (access == null || access.isEmpty) return true;

      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final after = prefs.getString(_prefsLastCheck) ??
          DateTime.now().toUtc().subtract(const Duration(minutes: 15)).toIso8601String();

      Future<Response<dynamic>> fetch(String token) => dio.get(
            '/notifications/since',
            queryParameters: {'after': after},
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );

      Response<dynamic> response;
      try {
        response = await fetch(access);
      } on DioException catch (e) {
        if (e.response?.statusCode != 401) return true;
        final refresh = await storage.read(key: AppConstants.refreshTokenKey);
        if (refresh == null) return true;
        final renewed = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
        access = renewed.data['accessToken'] as String?;
        if (access == null) return true;
        await storage.write(key: AppConstants.accessTokenKey, value: access);
        final newRefresh = renewed.data['refreshToken'] as String?;
        if (newRefresh != null) await storage.write(key: AppConstants.refreshTokenKey, value: newRefresh);
        response = await fetch(access);
      }

      final items = (response.data is Map ? response.data['data'] : null) as List? ?? const [];
      if (items.isEmpty) return true;
      final plugin = await _localNotifications();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'Уведомления Opero',
          channelDescription: 'Новые операции, задачи и сделки вашей организации',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      var latest = after;
      for (final raw in items) {
        final n = Map<String, dynamic>.from(raw as Map);
        final created = (n['created_at'] ?? n['createdAt'] ?? '').toString();
        await plugin.show(
          id: created.hashCode & 0x7fffffff,
          title: (n['title'] ?? 'Opero').toString(),
          body: (n['body'] ?? '').toString(),
          notificationDetails: details,
        );
        if (created.compareTo(latest) > 0) latest = created;
      }
      await prefs.setString(_prefsLastCheck, latest);
    } catch (e) {
      debugPrint('[PushService] background check failed: $e');
    }
    return true;
  });
}
