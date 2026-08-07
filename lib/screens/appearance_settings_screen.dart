import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../theme/app_background.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  Widget _buildSwatch(Color? color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.white,
        border: Border.all(color: color == null ? Colors.grey : Colors.white, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => Scaffold(
        backgroundColor: ThemeController.instance.backgroundData.color,
        bottomNavigationBar: const DebugScreenTag('appearance_settings_screen.dart'),
        appBar: AppBar(
          centerTitle: true,
          title: Text(AppStrings.t('appearance_settings_title')),
          actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
          Text(
            AppStrings.t('choose_a_theme_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: ThemeController.instance.backgroundData.titleTextColor,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<AppThemeKey>(
            valueListenable: ThemeController.instance.current,
            builder: (context, currentKey, _) {
              return Column(
                children: [
                  for (final entry in kAppThemes.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: entry.key == currentKey ? entry.value.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => ThemeController.instance.setTheme(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Row(
                                  children: [
                                    _buildSwatch(entry.value.primary),
                                    Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: _buildSwatch(entry.value.secondary),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-16, 0),
                                      child: _buildSwatch(entry.value.accent),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value.label,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                                if (entry.key == currentKey)
                                  Icon(Icons.check_circle, color: entry.value.primary, size: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.t('choose_a_background_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: ThemeController.instance.backgroundData.titleTextColor,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<AppBackgroundKey>(
            valueListenable: ThemeController.instance.currentBackground,
            builder: (context, currentKey, _) {
              return Column(
                children: [
                  for (final entry in kAppBackgrounds.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: entry.key == currentKey ? (entry.value.color ?? Colors.grey) : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => ThemeController.instance.setBackground(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                _buildSwatch(entry.value.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value.label,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                                if (entry.key == currentKey)
                                  Icon(Icons.check_circle, color: entry.value.color ?? Colors.grey, size: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}
