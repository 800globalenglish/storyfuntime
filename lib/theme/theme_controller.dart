import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();

  final ValueNotifier<AppThemeKey> current = ValueNotifier(AppThemeKey.ocean);

  AppThemeData get data => kAppThemes[current.value]!;

  void setTheme(AppThemeKey key) {
    current.value = key;
    // TODO: call ApiService to persist to backend
  }
}
