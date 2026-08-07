import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_background.dart';

class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();

  final ValueNotifier<AppThemeKey> current = ValueNotifier(AppThemeKey.ocean);
  final ValueNotifier<AppBackgroundKey> currentBackground = ValueNotifier(AppBackgroundKey.original);

  AppThemeData get data => kAppThemes[current.value]!;
  AppBackgroundData get backgroundData => kAppBackgrounds[currentBackground.value]!;

  /// Resolves what a button of the given role should be colored right now:
  /// the active background's override if it has one, otherwise the button
  /// theme's color for that role. This is the only thing screens should call.
  Color buttonColor(ButtonRole role) {
    final bg = backgroundData;
    switch (role) {
      case ButtonRole.primary:
        return bg.primaryOverride ?? data.primary;
      case ButtonRole.secondary:
        return bg.secondaryOverride ?? data.secondary;
      case ButtonRole.accent:
        return bg.accentOverride ?? data.accent;
    }
  }

  /// Companion to buttonColor(): resolves the button's foreground/text
  /// color, since some background overrides (e.g. Purple's cream accent
  /// button) need dark text instead of the usual white.
  Color buttonTextColor(ButtonRole role) {
    final bg = backgroundData;
    switch (role) {
      case ButtonRole.primary:
        return bg.primaryTextOverride ?? Colors.white;
      case ButtonRole.secondary:
        return bg.secondaryTextOverride ?? Colors.white;
      case ButtonRole.accent:
        return bg.accentTextOverride ?? Colors.white;
    }
  }

  /// Single listenable covering both the button theme and the background,
  /// so screens need one rebuild trigger instead of nesting two builders.
  Listenable get listenable => Listenable.merge([current, currentBackground]);

  void setTheme(AppThemeKey key) {
    current.value = key;
    // TODO: call ApiService to persist to backend
  }

  void setBackground(AppBackgroundKey key) {
    currentBackground.value = key;
    // TODO: call ApiService to persist to backend
  }
}
