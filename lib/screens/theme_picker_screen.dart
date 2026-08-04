import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  Widget _buildSwatch(Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('theme_picker_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Choose a Theme'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: ValueListenableBuilder<AppThemeKey>(
        valueListenable: ThemeController.instance.current,
        builder: (context, currentKey, _) {
          return ListView(
            padding: const EdgeInsets.all(24.0),
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
    );
  }
}
