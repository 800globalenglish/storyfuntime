import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('language_settings_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Language / Idioma / 语言'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: AppStrings.languageCode,
        builder: (context, currentCode, _) {
          return ListView(
            children: [
              for (final language in supportedLanguages)
                RadioListTile<String>(
                  secondary: Text(language.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(language.label, style: const TextStyle(fontSize: 18)),
                  value: language.code,
                  groupValue: currentCode,
                  onChanged: (code) {
                    if (code == null) return;
                    AppStrings.setLanguage(code);
                    Navigator.pop(context);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
