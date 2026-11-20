// Messenger moderation (App Store Guideline 1.2): report a message, block its
// sender, unblock. Run on a simulator against a test server:
//   flutter test integration_test/chat_moderation_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
import 'dart:convert';
import 'dart:io';
import 'package:company_os/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

const _base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');

Future<Map<String, dynamic>> _http(String method, String path, {String? token, Object? body}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse('$_base$path'));
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 300) throw Exception('$method $path -> ${res.statusCode} $text');
    return text.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(text) as Map);
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('messenger: report and block', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    (await SharedPreferences.getInstance()).clear();

    // An owner and an employee in one organization; the employee writes two messages.
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final ownerEmail = 'mod_$stamp@example.test';
    final empEmail = 'mod_emp_$stamp@example.test';
    const password = 'Secret123';
    final owner = await _http('POST', '/auth/register', body: {'email': ownerEmail, 'password': password, 'fullName': 'Владелец', 'companyName': 'Модерация $stamp'});
    final ownerToken = owner['accessToken'] as String;
    await _http('POST', '/employees', token: ownerToken, body: {'fullName': 'Нарушитель Тестов', 'email': empEmail, 'password': password, 'role': 'MANAGER'});
    final empToken = (await _http('POST', '/auth/login', body: {'email': empEmail, 'password': password}))['accessToken'] as String;
    final rooms = (await _http('GET', '/chat/rooms', token: ownerToken))['data'] as List;
    final roomId = (rooms.first as Map)['id'];
    await _http('POST', '/chat/rooms/$roomId/messages', token: empToken, body: {'content': 'Плохое сообщение'});
    await _http('POST', '/chat/rooms/$roomId/messages', token: empToken, body: {'content': 'Второе сообщение'});

    app.main();
    await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 30));
    await typeInto(tester, nthField(0), ownerEmail);
    await typeInto(tester, nthField(1), password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);
    if (find.text('Войти').evaluate().isNotEmpty) await tapOn(tester, find.text('Войти').last);
    await waitFor(tester, find.text('1'), timeout: const Duration(seconds: 30));
    await enterPin(tester, testPin);
    await settle(tester, 6);
    await enterPin(tester, testPin);
    await settle(tester, 10);
    if (find.text('Позже').evaluate().isNotEmpty) await tapOn(tester, find.text('Позже'));
    await waitFor(tester, find.text('Главная'), timeout: const Duration(seconds: 30));

    await scrollToAndTap(tester, find.text('Мессенджер'));
    await tapOn(tester, find.text('Общий чат'));
    await waitFor(tester, find.text('Плохое сообщение'));
    await screenshot(tester, 'mod_01_chat');

    // Report
    await tester.longPress(find.text('Плохое сообщение'));
    await settle(tester, 8);
    expect(find.text('Ответить'), findsOneWidget);
    await screenshot(tester, 'mod_02_actions');
    await tapOn(tester, find.text('Пожаловаться'));
    await waitFor(tester, find.text('Причина жалобы'));
    await screenshot(tester, 'mod_03_reasons');
    await tapOn(tester, find.text('Оскорбление или угрозы'));
    await waitGone(tester, find.text('Плохое сообщение'));
    expect(find.text('Второе сообщение'), findsOneWidget);
    report('reported message disappeared; the other one stays');

    // Block
    await settle(tester, 30);
    await tester.longPress(find.text('Второе сообщение'));
    await settle(tester, 8);
    await tapOn(tester, find.textContaining('Заблокировать Нарушитель'));
    await waitFor(tester, find.text('Заблокировать?'));
    await screenshot(tester, 'mod_04_block_confirm');
    await tapOn(tester, find.text('Заблокировать'));
    await waitGone(tester, find.text('Второе сообщение'));
    final blocked = (await serverGet('/chat/blocks'))['data'] as List;
    expect(blocked, hasLength(1));
    report('blocked sender: their messages are gone, server has the block');

    // Unblock
    await tapOn(tester, find.byTooltip('Заблокированные'));
    await waitFor(tester, find.text('Нарушитель Тестов'));
    await screenshot(tester, 'mod_05_blocked_list');
    await tapOn(tester, find.text('Разблокировать'));
    await waitFor(tester, find.text('Вы никого не заблокировали'));
    await tester.tapAt(const Offset(20, 100));
    await settle(tester, 10);
    await waitFor(tester, find.text('Второе сообщение'), timeout: const Duration(seconds: 15));
    expect(find.text('Плохое сообщение'), findsNothing);
    report('unblocked: messages are back, the reported one stays hidden');

    await _http('DELETE', '/auth/account', token: empToken, body: {'password': password});
    await _http('DELETE', '/auth/account', token: ownerToken, body: {'password': password});
  });
}
