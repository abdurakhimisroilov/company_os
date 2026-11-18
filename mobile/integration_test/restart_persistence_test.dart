// Runs after release_flow_test.dart as a brand-new app process: checks that the
// session, PIN, organization and the saved data survived the restart.
// `flutter test` reinstalls the app, which wipes its preferences (the keychain
// survives), so the saved theme is checked in release_flow_test instead.
import 'package:company_os/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('data survives closing and reopening the app', (tester) async {
    app.main();

    // A saved session opens on the PIN lock, not the login form.
    await waitFor(tester, find.text('1'), timeout: const Duration(seconds: 30));
    expect(find.text('Добро пожаловать'), findsNothing);
    await screenshot(tester, 'r1_pin_lock');
    await enterPin(tester, testPin);

    await waitFor(tester, find.text('Общий результат'), timeout: const Duration(seconds: 30));
    await waitFor(tester, find.text('Тест Альфа'));
    await waitFor(tester, textWith('750 000'));
    await screenshot(tester, 'r2_dashboard_after_restart');

    await scrollToAndTap(tester, find.text('Финансы'));
    await waitFor(tester, find.textContaining('все ок прошло'));
    expect(textWith('1 000 000'), findsWidgets);
    report('after restart: session, PIN, organization "Тест Альфа", balance 750 000 and the 1 000 000 income are all still there');
    await screenshot(tester, 'r3_finance_after_restart');
  });
}
