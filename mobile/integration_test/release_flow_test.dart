// Mandatory release scenarios, run on a simulator against a test server:
//   flutter test integration_test/release_flow_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
// Run restart_persistence_test.dart afterwards: it relaunches the app as a new
// process and checks that everything created here is still there.
import 'dart:io';
import 'package:company_os/core/theme/app_colors.dart';
import 'package:company_os/core/theme/theme_controller.dart';
import 'package:company_os/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('COMPANY OS release scenarios', (tester) async {
    // Start from a clean device: no session, no PIN, light theme.
    await const FlutterSecureStorage().deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'ui_$stamp@example.test';
    const companyA = 'Тест Альфа';
    final productName = 'Товар UI $stamp';

    var step = 'start';
    traceOverflows(() => step);
    app.main();
    await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 30));
    await screenshot(tester, '01_login');

    // ── Register ────────────────────────────────────────────────────────────
    step = 'Register';
    await tapOn(tester, find.text('Зарегистрироваться'));
    await waitFor(tester, find.text('Подтвердите пароль'));
    await typeInto(tester, nthField(0), 'Тест Пользователь');
    await typeInto(tester, nthField(1), email);
    await typeInto(tester, nthField(3), companyA);
    await typeInto(tester, nthField(4), 'Secret123');
    await typeInto(tester, nthField(5), 'Secret123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 10);
    // On Android "done" on the last field already submits the form, so the
    // button may be gone (or going) by now.
    final registerButton = find.widgetWithText(InkWell, 'Зарегистрироваться');
    if (registerButton.evaluate().isNotEmpty) {
      await tester.tap(registerButton.first, warnIfMissed: false);
      await settle(tester, 4);
    }

    // ── PIN setup ───────────────────────────────────────────────────────────
    step = 'PIN setup';
    await waitFor(tester, find.text('1'), timeout: const Duration(seconds: 30));
    await enterPin(tester, testPin);
    await settle(tester, 6);
    await enterPin(tester, testPin);
    await settle(tester, 10);
    if (find.text('Позже').evaluate().isNotEmpty) await tapOn(tester, find.text('Позже'));

    // ── Dashboard starts empty ──────────────────────────────────────────────
    step = 'Dashboard starts empty';
    await waitFor(tester, find.text('Общий результат'), timeout: const Duration(seconds: 30));
    await waitFor(tester, find.text(companyA));
    report('registered and reached the dashboard of "$companyA"');
    await screenshot(tester, '02_dashboard_empty');

    // ── Income 1 000 000 UZS ────────────────────────────────────────────────
    step = 'Income 1 000 000 UZS';
    await tapOn(tester, find.byIcon(Icons.add_rounded));
    await tapOn(tester, find.text('Поступление'));
    await waitFor(tester, find.text('Сохранить поступление'));
    await typeInto(tester, nthField(0), '1000000');
    await tapOn(tester, find.text('Банк'));
    await typeInto(tester, fieldWithHint('Выберите клиента или введите плательщика'), 'Клиент1');
    await typeInto(tester, fieldWithHint('Комментарий к платежу...'), 'все ок прошло');
    await screenshot(tester, '03_income_form');
    await tapOn(tester, find.text('Сохранить поступление'));
    await waitGone(tester, find.text('Сохранить поступление'));

    await waitFor(tester, textWith('1 000 000'));
    await screenshot(tester, '04_dashboard_after_income');
    final stats = await serverGet('/dashboard/stats?period=month');
    expect(stats['income'], 1000000);
    expect(stats['totalBalance'], 1000000);
    final txs = (await serverGet('/finance/transactions'))['data'] as List;
    expect(txs, hasLength(1));
    final tx = Map<String, dynamic>.from(txs.first as Map);
    expect(tx['payment_method'], 'bank');
    expect(tx['account_type'], 'BANK');
    expect(tx['counterparty_name'], 'Клиент1');
    expect(tx['description'], 'все ок прошло');
    final today = DateTime.now();
    final day = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    expect(tx['transaction_date'], day);
    report('income 1 000 000 saved in the database (bank, Клиент1, $day) and shown on the dashboard');

    // ── Expense recalculates the balance ────────────────────────────────────
    step = 'Expense recalculates the balance';
    await tapOn(tester, find.byIcon(Icons.add_rounded));
    await tapOn(tester, find.text('Расход'));
    await waitFor(tester, find.text('Сохранить расход'));
    await typeInto(tester, nthField(0), '250000');
    await tapOn(tester, find.text('Банк'));
    await tapOn(tester, find.text('Сохранить расход'));
    await waitGone(tester, find.text('Сохранить расход'));
    await waitFor(tester, textWith('750 000'));
    final after = await serverGet('/dashboard/stats?period=month');
    expect(after['totalBalance'], 750000);
    expect(after['expenses'], 250000);
    report('expense 250 000 saved; balance recalculated to 750 000 on screen and in the database');
    await screenshot(tester, '05_dashboard_after_expense');

    // ── Finance screen lists both operations ────────────────────────────────
    step = 'Finance screen lists both operations';
    await scrollToAndTap(tester, find.text('Финансы'));
    await waitFor(tester, find.text('История операций'));
    await waitFor(tester, find.textContaining('все ок прошло'));
    await screenshot(tester, '06_finance');
    report('finance screen lists the saved operations');
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));

    // ── Add a product ───────────────────────────────────────────────────────
    step = 'Add a product';
    await tapOn(tester, find.text('Склад'));
    await tapOn(tester, find.text('Товар'));
    await waitFor(tester, find.text('Название товара *'));
    await typeInto(tester, fieldWithHint('Например, Смартфон Galaxy S24'), productName);
    // Purchase price, then the required selling price (both show the "0 сум" placeholder).
    await typeInto(tester, fieldWithHint('0 сум').first, '3000');
    await typeInto(tester, fieldWithHint('0 сум').last, '5000');
    await tapOn(tester, find.text('Добавить товар'));
    await waitGone(tester, find.text('Название товара *'));
    await waitFor(tester, find.text(productName), timeout: const Duration(seconds: 20));
    final products = (await serverGet('/inventory/products'))['data'] as List;
    expect(products.map((p) => (p as Map)['name']), contains(productName));
    report('product "$productName" saved and listed in the warehouse');
    await screenshot(tester, '07_inventory');
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));

    // ── Document: open a stored file through the real viewer path ───────────
    step = 'Document: open a stored file through the real viewer path';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/договор_$stamp.txt')..writeAsStringSync('COMPANY OS test document');
    await api.uploadFile(file.path, path: '/documents/upload');
    await scrollToAndTap(tester, find.text('Документы'));
    await waitFor(tester, find.textContaining('договор_$stamp'));
    await screenshot(tester, '08_documents');
    // Opening hands the file to the native iOS viewer, which the test cannot
    // close, so that part runs last.
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));

    // ── Second organization is separate, switching back restores data ───────
    step = 'Second organization is separate, switching back restores data';
    await tapOn(tester, find.text(companyA));
    await waitFor(tester, find.text('Мои организации'));
    await tapOn(tester, find.text('Добавить другую организацию'));
    await waitFor(tester, find.text('Название организации *'));
    await typeInto(tester, fieldWithHint('ООО "АгроЭкспорт", ИП "Ибрагимов"...'), 'Тест Бета');
    await tapOn(tester, find.text('Создать и войти'));
    await waitFor(tester, find.text('Тест Бета'), timeout: const Duration(seconds: 20));
    await waitFor(tester, find.text('Общий результат'));
    await settle(tester, 10);
    expect(textWith('1 000 000'), findsNothing);
    expect(textWith('750 000'), findsNothing);
    final beta = await serverGet('/dashboard/stats');
    expect(beta['totalBalance'], 0);
    expect(beta['totalProducts'], 0);
    report('new organization "Тест Бета" created and shows none of Альфа\'s money or products');
    await screenshot(tester, '10_org_beta');

    await tapOn(tester, find.text('Тест Бета'));
    await waitFor(tester, find.text('Мои организации'));
    await tapOn(tester, find.text(companyA).last);
    await waitFor(tester, textWith('750 000'), timeout: const Duration(seconds: 20));
    report('switched back to "$companyA": balance 750 000 is shown again');

    // ── Dark mode across the main screens ───────────────────────────────────
    step = 'Dark mode across the main screens';
    await tapOn(tester, find.text('Ещё'));
    await waitFor(tester, find.text('Тёмная тема'));
    await tapOn(tester, find.text('Тёмная тема'));
    await settle(tester, 10);
    expect(ThemeController.instance.isDark, isTrue);
    expect(AppColors.isDark, isTrue);
    // The choice is written to disk and is what the app reads at startup.
    await prefs.reload();
    expect(prefs.getString('app_theme_mode'), 'dark');
    await ThemeController.instance.load();
    expect(ThemeController.instance.isDark, isTrue);
    expectNoWhiteSurfaces(tester, 'settings');
    await screenshot(tester, '11_dark_settings');
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));

    Future<void> darkScreen(String tile, String readyText, String name) async {
      await scrollToAndTap(tester, find.text(tile));
      await waitFor(tester, find.textContaining(readyText));
      expectNoWhiteSurfaces(tester, name);
      await screenshot(tester, 'dark_$name');
      await goBack(tester);
      await waitFor(tester, find.text('Главная'));
    }

    expectNoWhiteSurfaces(tester, 'dashboard');
    await screenshot(tester, 'dark_dashboard');
    await darkScreen('Финансы', 'История операций', 'finance');
    await darkScreen('Склад', productName, 'inventory');
    await darkScreen('Документы', 'договор_$stamp', 'documents');
    await darkScreen('Задания', 'Задания', 'tasks');
    await darkScreen('Отчёты и аналитика', 'Аналитика и отчёты', 'reports');
    await darkScreen('Сделки и клиенты', 'Сделка', 'deals');
    await darkScreen('Продажи', 'Продажа', 'sales');
    await darkScreen('Поставки', 'Поставка', 'shipments');
    await darkScreen('Клиенты', 'Клиент', 'customers');
    await darkScreen('Поставщики', 'Поставщик', 'suppliers');
    await darkScreen('Мессенджер', 'Общий чат', 'messenger');
    await tapOn(tester, find.byIcon(Icons.add_rounded));
    await tapOn(tester, find.text('Поступление'));
    await waitFor(tester, find.text('Сохранить поступление'));
    expectNoWhiteSurfaces(tester, 'add_income');
    await screenshot(tester, 'dark_add_income');
    await goBack(tester);
    await waitFor(tester, find.text('Главная'));
    report('dark mode applied on every main screen with no white surfaces');

    // ── Open the uploaded document in the system viewer (last: it covers the app)
    step = 'Open document';
    await scrollToAndTap(tester, find.text('Документы'));
    print('ACCOUNT:$email');
    await waitFor(tester, find.textContaining('договор_$stamp'));
    await tester.tap(find.textContaining('договор_$stamp').first);
    // iOS stops drawing Flutter frames while its document viewer covers the app,
    // so from here on wait in real time and let the runner capture the screen.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
    print('SCREENSHOT:12_document_opened');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    report('uploaded document downloaded and opened in the system viewer (see screenshot 12)');
  });
}
