import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app-wide light/dark preference. Read synchronously by [AppColors]
/// (so design tokens resolve without a BuildContext) and listened to by the
/// root [MaterialApp] so a toggle rebuilds the whole tree.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'carebike_dark_mode';

  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Load the saved preference once at startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _isDark = false;
    }
    notifyListeners();
  }

  /// Flip the theme and persist the choice.
  Future<void> toggle() => setDark(!_isDark);

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, _isDark);
    } catch (_) {/* non-fatal */}
  }
}
