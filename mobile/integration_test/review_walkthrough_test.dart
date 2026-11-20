// Slow walkthrough of the App Review flow, for a simulator screen recording:
// register, main features, logout/login, chat report/block/unblock, account deletion.
// Needs the demo account (backend/scripts/seed-demo.js) on the target server.
//   flutter test integration_test/review_walkthrough_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --dart-define=DEMO_PASSWORD=...
import 'package:company_os/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

const _demoEmail = 'demo@opero.app';
const _demoPassword = String.fromEnvironment('DEMO_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Review walkthrough', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    (await SharedPreferences.getInstance()).clear();
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final testEmail = 'review_$stamp@example.test';
    const testPassword = 'Review2026';

    Future<void> pause([double seconds = 1.6]) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pinIfAsked() async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        if (find.text('Главная').evaluate().isNotEmpty) return;
        if (find.text('1').evaluate().isNotEmpty) {
          await pause(0.8);
          await enterPin(tester, testPin);
          await settle(tester, 6);
          if (find.text('Главная').evaluate().isEmpty && find.text('1').evaluate().isNotEmpty) {
            await enterPin(tester, testPin);
            await settle(tester, 8);
          }
          break;
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      await settle(tester, 6);
      if (find.text('Позже').evaluate().isNotEmpty) await tapOn(tester, find.text('Позже'));
      await waitFor(tester, find.text('Главная'), timeout: const Duration(seconds: 30));
    }

    Future<void> login(String email, String password) async {
      await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 30));
      await pause(1);
      await typeInto(tester, nthField(0), email);
      await pause(0.6);
      await typeInto(tester, nthField(1), password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 6);
      if (find.text('Войти').evaluate().isNotEmpty && find.text('Главная').evaluate().isEmpty) {
        final button = find.text('Войти');
        if (button.evaluate().isNotEmpty) await tester.tap(button.last, warnIfMissed: false);
        await settle(tester, 4);
      }
      await pinIfAsked();
      await pause(2);
    }

    Future<void> logout() async {
      await tapOn(tester, find.text('Ещё'));
      await pause(1.2);
      await scrollToAndTap(tester, find.text('Выйти из аккаунта'));
      await pause(1);
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Выйти'));
      await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 20));
      await pause(1.5);
    }

    Future<void> openActions(Finder message, String messageText) async {
      for (var i = 0; i < 4; i++) {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester, 8);
        await tester.ensureVisible(message);
        await tester.longPress(message, warnIfMissed: false);
        await settle(tester, 8);
        if (find.text('Ответить').evaluate().isNotEmpty) return;
        // Fallback: call the bubble's long-press handler directly.
        final detector = find.ancestor(of: find.textContaining(messageText, skipOffstage: false), matching: find.byType(GestureDetector));
        final handlers = detector.evaluate().map((e) => (e.widget as GestureDetector).onLongPress).whereType<VoidCallback>();
        if (handlers.isNotEmpty) {
          handlers.first();
          await settle(tester, 8);
          if (find.text('Ответить').evaluate().isNotEmpty) return;
        }
        await pause(1);
      }
      print('SNAP');
      await pause(3);
      final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ');
      throw StateError('message actions did not open. On screen: $texts');
    }

    Future<void> visit(String tile, String readyText) async {
      await scrollToAndTap(tester, find.text(tile));
      await waitFor(tester, find.textContaining(readyText));
      await pause(2.2);
      await goBack(tester);
      await waitFor(tester, find.text('Главная'));
      await pause(0.6);
    }

    print('REC_START');
    await pause(2.5);
    app.main();
    await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 30));
    await pause(2);

    // 1. Registration
    await tapOn(tester, find.text('Зарегистрироваться'));
    await waitFor(tester, find.text('Подтвердите пароль'));
    await pause(1);
    await typeInto(tester, nthField(0), 'Тест Ревью');
    await typeInto(tester, nthField(1), testEmail);
    await typeInto(tester, nthField(3), 'Тестовая компания');
    await typeInto(tester, nthField(4), testPassword);
    await typeInto(tester, nthField(5), testPassword);
    await pause(1.2);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 10);
    final registerButton = find.widgetWithText(InkWell, 'Зарегистрироваться');
    if (registerButton.evaluate().isNotEmpty) {
      await tester.tap(registerButton.first, warnIfMissed: false);
      await settle(tester, 4);
    }
    await pinIfAsked();
    await pause(2);

    // 2. A first income in the new company
    await tapOn(tester, find.byIcon(Icons.add_rounded));
    await pause(0.8);
    await tapOn(tester, find.text('Поступление'));
    await waitFor(tester, find.text('Сохранить поступление'));
    await typeInto(tester, nthField(0), '500000');
    await tapOn(tester, find.text('Банк'));
    await typeInto(tester, fieldWithHint('Выберите клиента или введите плательщика'), 'Розничный покупатель');
    await typeInto(tester, fieldWithHint('Комментарий к платежу...'), 'Первая продажа');
    await pause(1.2);
    await tapOn(tester, find.text('Сохранить поступление'));
    await waitGone(tester, find.text('Сохранить поступление'));
    await pause(2.5);

    // 3. Log out, log in to the demo account with sample data
    await logout();
    await login(_demoEmail, _demoPassword);
    await pause(1);
    await visit('Финансы', 'История операций');
    await visit('Продажи', 'Продажа');
    await visit('Сделки и клиенты', 'Сделка');
    await visit('Задания', 'Задания');
    await visit('Документы', 'Договоры');
    await visit('Отчёты и аналитика', 'Аналитика и отчёты');

    // 4. Team chat: block, unblock, report
    await scrollToAndTap(tester, find.text('Мессенджер'));
    await pause(1.2);
    await tapOn(tester, find.text('Общий чат'));
    final target = find.textContaining('Образцы тканей');
    await waitFor(tester, target);
    await pause(2);

    await openActions(target, 'Образцы тканей');
    await pause(1.5);
    await tapOn(tester, find.textContaining('Заблокировать '));
    await waitFor(tester, find.text('Заблокировать?'));
    await pause(2);
    await tapOn(tester, find.text('Заблокировать'));
    await waitGone(tester, target);
    await pause(3);

    await tapOn(tester, find.byTooltip('Заблокированные'));
    await waitFor(tester, find.text('Разблокировать'));
    await pause(2);
    await tapOn(tester, find.text('Разблокировать'));
    await waitFor(tester, find.text('Вы никого не заблокировали'));
    await pause(1.5);
    await tester.tapAt(const Offset(20, 120));
    await settle(tester, 10);
    await waitFor(tester, target, timeout: const Duration(seconds: 15));
    await pause(2.5);

    await settle(tester, 30);
    await openActions(target, 'Образцы тканей');
    await pause(1.5);
    await tapOn(tester, find.text('Пожаловаться'));
    await waitFor(tester, find.text('Причина жалобы'));
    await pause(1.5);
    await tapOn(tester, find.text('Неприемлемый контент'));
    await waitGone(tester, target);
    await pause(3.5);
    await goBack(tester);
    await pause(0.6);
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));

    // 5. Delete the test account
    await logout();
    await login(testEmail, testPassword);
    await tapOn(tester, find.text('Ещё'));
    await pause(1.2);
    await scrollToAndTap(tester, find.text('Удалить аккаунт'));
    await waitFor(tester, find.text('Удаление аккаунта'));
    await pause(2.5);
    await typeInto(tester, find.byType(TextField).last, testPassword);
    await pause(1);
    await tapOn(tester, find.text('Удалить навсегда'));
    await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 20));
    await pause(3);
    print('REC_STOP');
    report('walkthrough complete; test account deleted');
  });
}
