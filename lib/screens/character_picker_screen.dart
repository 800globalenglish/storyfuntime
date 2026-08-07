import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'book_detail_screen.dart';
import '../utils/character_grouping.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/theme_controller.dart';

class CharacterPickerScreen extends StatefulWidget {
  final String bookId;

  const CharacterPickerScreen({super.key, required this.bookId});

  @override
  State<CharacterPickerScreen> createState() => _CharacterPickerScreenState();
}

class _CharacterPickerScreenState extends State<CharacterPickerScreen> {
  final _apiService = ApiService();
  late Future<List<Character>> _charactersFuture;
  final Set<String> _selectedIds = {};
  bool _isSubmitting = false;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    _charactersFuture = _apiService.getAllCharactersForUser();
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _next() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('pick_at_least_one_character'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.copyCharactersToBook(
        bookId: widget.bookId,
        characterIds: _selectedIds.toList(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: widget.bookId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.t('failed_to_add_characters')} $e')),
        );
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => Scaffold(
        backgroundColor: ThemeController.instance.backgroundData.color,
        appBar: AppBar(
          centerTitle: true,
          title: Text(AppStrings.t('choose_characters_title')),
          actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
        ),
      body: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}'));
          }
          final characters = snapshot.data ?? [];
          if (characters.isEmpty) {
            return Center(
              child: Text(
                AppStrings.t('no_characters_yet_hint'),
                style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
              ),
            );
          }

          final groups = groupCharacters(characters);

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: groups.length > 4 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final character = group.representative;
              final isSelected = _selectedIds.contains(character.id);

              return GestureDetector(
                onTap: () => _toggle(character.id),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: character.cartoonAvatarUrl != null
                                ? Image.network(
                              '${ApiService.baseUrl}${character.cartoonAvatarUrl}',
                              fit: BoxFit.cover,
                            )
                                : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.person, size: 48),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected ? Border.all(color: Colors.blue, width: 4) : null,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.blue : Colors.white,
                              size: 28,
                            ),
                          ),
                          // NEW - "in N stories" badge, only shown when the same
                          // avatar appears in more than one book.
                          if (group.count > 1)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  AppStrings.t('in_n_stories').replaceFirst('{count}', '${group.count}'),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      character.name,
                      style: TextStyle(fontWeight: FontWeight.bold, color: ThemeController.instance.backgroundData.bodyTextColor),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedIds.isNotEmpty ? Colors.green : null,
                    foregroundColor: _selectedIds.isNotEmpty ? Colors.white : null,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    '${AppStrings.t('next_selected_prefix')} (${_selectedIds.length} ${AppStrings.t('selected_suffix')})',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
            const DebugScreenTag('character_picker_screen.dart'),
          ],
        ),
      ),
      ),
    );
  }
}