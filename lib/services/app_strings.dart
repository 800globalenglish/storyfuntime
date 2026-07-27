import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages. To add a new one: create assets/lang/{code}.json
/// (copy en.json and translate every value), then add it to this list.
class AppLanguage {
  final String code;
  final String label;
  const AppLanguage(this.code, this.label);
}

const supportedLanguages = [
  AppLanguage('en', 'English'),
  AppLanguage('es', 'Español'),
  AppLanguage('zh', '中文'),
];

/// Loads translated text from assets/lang/{code}.json and makes it
/// available everywhere via AppStrings.t('some_key').
///
/// Usage in a screen: Text(AppStrings.t('welcome_back'))
/// If a key is missing from a translation file, it falls back to the
/// English value, so nothing ever shows up blank.
class AppStrings {
  static const _prefsKey = 'language_code';

  /// Other widgets can listen to this to rebuild when the language changes
  /// (see LanguageAware below, used once at the top of the app).
  static final ValueNotifier<String> languageCode = ValueNotifier('en');

  static Map<String, String> _current = {};
  static Map<String, String> _english = {};

  /// Call once at startup, before runApp - loads the saved language
  /// (or English by default).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? 'en';
    _english = await _loadJson('en');
    _current = saved == 'en' ? _english : await _loadJson(saved);
    languageCode.value = saved;
  }

  /// Switches language immediately and remembers the choice for next time.
  static Future<void> setLanguage(String code) async {
    _current = code == 'en' ? _english : await _loadJson(code);
    languageCode.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  static Future<Map<String, String>> _loadJson(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/lang/$code.json');
      return Map<String, String>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  /// Looks up [key] in the current language, falling back to English,
  /// then to the key itself if it's missing everywhere (so a translation
  /// gap shows up as an odd-looking key rather than a blank space -
  /// easy to spot and fix).
  static String t(String key) {
    return _current[key] ?? _english[key] ?? key;
  }
}

/// Wrap the top of the app in this once - it rebuilds everything below it
/// whenever the language changes, so every screen using AppStrings.t()
/// updates immediately without any extra plumbing.
class LanguageAware extends StatelessWidget {
  final Widget child;
  const LanguageAware({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.languageCode,
      builder: (context, _, __) => child,
    );
  }
}
