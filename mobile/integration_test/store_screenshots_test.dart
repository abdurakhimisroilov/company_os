// Captures App Store / Play screenshots of the main screens with sample data.
//   cd backend && BASE_URL=http://localhost:3000 DEMO_EMAIL=shots@opero.app \
//     DEMO_PASSWORD=Screens2026 node scripts/seed-demo.js
//   flutter test integration_test/store_screenshots_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
// The runner script saves a screenshot for every "SCREENSHOT:<name>" line.
import 'package:company_os/core/theme/theme_controller.dart';
import 'package:company_os/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

const _email = String.fromEnvironment('SHOTS_EMAIL', defaultValue: 'shots@opero.app');
const _password = String.fromEnvironment('SHOTS_PASSWORD', defaultValue: 'Screens2026');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Notifications stay off so the system permission prompt does not cover the screens.
    await prefs.setBool('push_enabled', false);

    app.main();
    await waitFor(tester, find.text('Добро пожаловать'), timeout: const Duration(seconds: 30));
    await typeInto(tester, nthField(0), _email);
    await typeInto(tester, nthField(1), _password);
    await tapOn(tester, find.text('Войти').last);

    await waitFor(tester, find.text('1'), timeout: const Duration(seconds: 30));
    await enterPin(tester, testPin);
    await settle(tester, 6);
    await enterPin(tester, testPin);
    await settle(tester, 10);
    if (find.text('Позже').evaluate().isNotEmpty) await tapOn(tester, find.text('Позже'));

    await waitFor(tester, find.text('Общий результат'), timeout: const Duration(seconds: 30));
    await waitFor(tester, textWith('12 110 000'));
    await settle(tester, 25);
    await screenshot(tester, '01_dashboard');

    Future<void> shot(String tile, String ready, String name) async {
      await scrollToAndTap(tester, find.text(tile));
      await waitFor(tester, find.textContaining(ready), timeout: const Duration(seconds: 20));
      await settle(tester, 10);
      await screenshot(tester, name);
      await goBack(tester);
      await waitFor(tester, find.text('Главная'));
    }

    await shot('Финансы', 'История операций', '02_finance');
    await shot('Склад', 'Ткань блэкаут', '03_inventory');
    await shot('Отчёты и аналитика', 'Расходы по категориям', '04_reports');
    await shot('Сделки и клиенты', 'Оснащение гостиницы', '05_deals');
    await shot('Задания', 'коммерческое предложение', '06_tasks');

    await ThemeController.instance.setDark(true);
    await settle(tester, 15);
    // Back to the top of the dashboard before the dark shot.
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    for (var i = 0; i < 8; i++) {
      await tester.drag(list.first, const Offset(0, 600), warnIfMissed: false);
      await settle(tester, 2);
    }
    await waitFor(tester, find.text('Общий результат'));
    await settle(tester, 20);
    await settle(tester, 10);
    await screenshot(tester, '07_dashboard_dark');
    await ThemeController.instance.setDark(false);
  });
}
