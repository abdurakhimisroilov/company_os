import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the selected [ThemeMode] (light / dark) and persists it with
/// `shared_preferences` so the choice survives app restarts.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  static const String _prefsKey = 'app_theme_mode';

  bool get isDark => value == ThemeMode.dark;

  /// Reads the saved choice. Call once in `main()` before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_prefsKey) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {
      value = ThemeMode.light;
    }
  }

  Future<void> setDark(bool dark) async {
    value = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, dark ? 'dark' : 'light');
    } catch (_) {
      // Persisting is best-effort; the in-memory choice still applies.
    }
  }

  Future<void> toggle() => setDark(!isDark);
}
