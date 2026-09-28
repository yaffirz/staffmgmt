import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the light / dark / system choice and persists it (per device) so it
/// survives a refresh/restart.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  static ThemeMode _parse(String? v) {
    switch (v) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _name(ThemeMode m) => m == ThemeMode.dark
      ? 'dark'
      : (m == ThemeMode.system ? 'system' : 'light');

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parse(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _name(mode));
  }

  /// Quick light/dark switch (used by the top-bar toggle).
  Future<void> setDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);
}
