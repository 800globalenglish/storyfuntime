import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'add_character_screen.dart';
import 'create_book_screen.dart';
import '../utils/fade_route.dart';
import '../utils/character_grouping.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class CharactersHomeScreen extends StatefulWidget {
  const CharactersHomeScreen({super.key});

  @override
  State<CharactersHomeScreen> createState() => _CharactersHomeScreenState();
}

class _CharactersHomeScreenState extends State<CharactersHomeScreen> {
  final _apiService = ApiService();
  late Future<List<Character>> _charactersFuture;
  final Set<String> _selectedIds = {};

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
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

  void _loadCharacters() {
    _charactersFuture = _apiService.getAllCharactersForUser();
  }

  void _refresh() {
    setState(() {
      _loadCharacters();
    });
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

  Future<void> _takePhoto() async {
    try {
      final libraryBookId = await _apiService.getLibraryBookId();
      if (mounted) {
        await Navigator.push(
          context,
          FadeRoute(page: AddCharacterScreen(bookId: libraryBookId)),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.t('failed_to_start')} $e')),
        );
      }
    }
  }

  Future<void> _goToNewBook() async {
    if (_selectedIds.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.t('create_book_without_characters_title')),
          content: Text(AppStrings.t('create_book_without_characters_content')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t('go_back')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.t('create_anyway')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    await Navigator.push(
      context,
      FadeRoute(page: CreateBookScreen(preSelectedCharacterIds: _selectedIds.toList())),
    );
    setState(() {
      _selectedIds.clear();
    });
    _refresh();
  }

  Future<void> _deleteCharacter(String characterId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.t('delete_character_title').replaceFirst('{name}', name)),
        content: Text(AppStrings.t('delete_character_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteCharacter(characterId: characterId);
      setState(() {
        _selectedIds.remove(characterId);
      });
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.t('failed_to_delete')} $e')),
        );
      }
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
          title: Text(AppStrings.t('characters_title')),
          actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
        ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: _buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                  foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                  shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                ),
                icon: const Icon(Icons.camera_alt, size: 32),
                label: Text(
                  AppStrings.t('new_character'),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Character>>(
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
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  AppStrings.t('no_characters_yet'),
                  style: TextStyle(fontSize: 18, color: ThemeController.instance.backgroundData.bodyTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final groups = groupCharacters(characters);

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
              final storyCount = group.count;
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
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                onPressed: () => _deleteCharacter(character.id, character.name),
                              ),
                            ),
                          ),
                          if (storyCount > 1)
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
                                  AppStrings.t('in_n_stories').replaceFirst('{count}', '$storyCount'),
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
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          final characters = snapshot.data ?? [];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (characters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: _buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _goToNewBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedIds.isNotEmpty ? Colors.green : null,
                          foregroundColor: _selectedIds.isNotEmpty ? Colors.white : null,
                          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                        ),
                        icon: const Icon(Icons.auto_stories, size: 32),
                        label: Text(
                          '${AppStrings.t('new_book')} (${_selectedIds.length})',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                const DebugScreenTag('characters_home_screen.dart'),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
