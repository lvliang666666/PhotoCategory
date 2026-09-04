import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'app_theme.dart';

class AppThemeController extends ChangeNotifier {
  int _colorIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;

  int get colorIndex => _colorIndex;
  ThemeMode get themeMode => _themeMode;
  ThemeColorOption get currentColorOption => AppTheme.colorOptions[_colorIndex];

  ThemeData get lightTheme => AppTheme.fromSeedColor(currentColorOption.seed,
      brightness: Brightness.light);

  ThemeData get darkTheme => AppTheme.fromSeedColor(currentColorOption.seed,
      brightness: Brightness.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _colorIndex = prefs.getInt(AppConstants.prefThemeColorIndex) ?? 0;
    if (_colorIndex < 0 || _colorIndex >= AppTheme.colorOptions.length) {
      _colorIndex = 0;
    }
    notifyListeners();
  }

  Future<void> setColorIndex(int index) async {
    if (index < 0 || index >= AppTheme.colorOptions.length) return;
    if (index == _colorIndex) return;

    _colorIndex = index;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefThemeColorIndex, index);
  }
}
