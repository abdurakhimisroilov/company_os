import 'package:company_os/core/di/injection.dart';
import 'package:company_os/core/network/api_client.dart';
import 'package:company_os/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testPin = '1234';

/// Pumps frames until [finder] matches or [timeout] passes. Unlike
/// pumpAndSettle it works with endless animations (shimmers, spinners).
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after ${timeout.inSeconds}s waiting for $finder');
}

Future<void> waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Still visible after ${timeout.inSeconds}s: $finder');
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await settle(tester, 3);
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester, 4);
}

Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await waitFor(tester, field);
  await tester.ensureVisible(field.first);
  await settle(tester, 2);
  await tester.enterText(field.first, text);
  await settle(tester, 2);
}

/// The TextFormField shown with [hint] as its placeholder.
Finder fieldWithHint(String hint) => find.ancestor(of: find.text(hint), matching: find.byType(TextFormField));

/// The n-th TextFormField on screen, in reading order.
Finder nthField(int n) => find.byType(TextFormField).at(n);

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tapOn(tester, find.text(digit).last);
  }
}

/// Lines starting with this marker make the runner script take a simulator screenshot.
Future<void> screenshot(WidgetTester tester, String name) async {
  await settle(tester, 8);
  print('SCREENSHOT:$name');
  // Leave the frame on screen while the outside script captures it.
  final end = DateTime.now().add(const Duration(milliseconds: 2500));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ApiClient get api => getIt<ApiClient>();

/// Reads straight from the server, bypassing every screen, to prove a value is in the database.
Future<Map<String, dynamic>> serverGet(String path) async {
  final response = await api.get(path);
  return Map<String, dynamic>.from(response.data as Map);
}

void report(String line) => print('RESULT: $line');

/// Fails if any visible surface is painted pure white while the dark theme is on.
void expectNoWhiteSurfaces(WidgetTester tester, String screen) {
  const white = Color(0xFFFFFFFF);
  final offenders = <String>[];
  for (final element in find.byWidgetPredicate((_) => true).evaluate()) {
    final w = element.widget;
    Color? color;
    if (w is Material && w.type != MaterialType.transparency) color = w.color;
    if (w is ColoredBox) color = w.color;
    if (w is Container && w.decoration is BoxDecoration) color = (w.decoration as BoxDecoration).color;
    if (w is Container && w.color != null) color = w.color;
    if (w is DecoratedBox && w.decoration is BoxDecoration) color = (w.decoration as BoxDecoration).color;
    if (color == null || color.toARGB32() != white.toARGB32()) continue;
    final box = element.renderObject;
    if (box is RenderBox && box.hasSize && box.size.width > 60 && box.size.height > 30) {
      offenders.add('${w.runtimeType} ${box.size.width.round()}×${box.size.height.round()}');
    }
  }
  expect(offenders, isEmpty, reason: 'White surfaces in dark mode on $screen: $offenders');
}

String _normalizeSpaces(String s) => s.replaceAll(RegExp(r'[   ]'), ' ');

/// Text containing [needle], treating the non-breaking spaces used as
/// thousands separators ("1 000 000") as ordinary spaces.
Finder textWith(String needle) => find.byWidgetPredicate((w) {
      if (w is Text) {
        final data = w.data ?? w.textSpan?.toPlainText();
        return data != null && _normalizeSpaces(data).contains(needle);
      }
      if (w is RichText) return _normalizeSpaces(w.text.toPlainText()).contains(needle);
      return false;
    });

/// Prints where each layout overflow happened (the screen it appeared on and the
/// widget that overflowed) before the framework reports it as a failure.
void traceOverflows(String Function() currentStep) {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      final ctx = details.context?.toString() ?? '';
      final info = details.informationCollector?.call().map((n) => n.toString()).take(6).join(' | ') ?? '';
      print('OVERFLOW during "${currentStep()}": $text | $ctx | $info');
    }
    original?.call(details);
  };
}

/// Scrolls the screen's main vertical list (up first, then down) until
/// [finder] is built, then taps it.
Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  bool missing() => finder.evaluate().isEmpty;
  for (final dy in const [400.0, -250.0]) {
    for (var i = 0; i < 30 && missing(); i++) {
      if (vertical.evaluate().isEmpty) break;
      await tester.drag(vertical.first, Offset(0, dy), warnIfMissed: false);
      await settle(tester, 3);
    }
  }
  await tapOn(tester, finder);
}

/// Goes back one screen the way the app's own back arrow does.
Future<void> goBack(WidgetTester tester) async {
  await rootNavigatorKey.currentState!.maybePop();
  await settle(tester, 6);
}
