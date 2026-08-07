import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../utils/character_grouping.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/theme_controller.dart';

class ChooseDifferentCharacterScreen extends StatefulWidget {
  final String bookId;
  final String currentCharacterId;

  const ChooseDifferentCharacterScreen({
    super.key,
    required this.bookId,
    required this.currentCharacterId,
  });

  @override
  State<ChooseDifferentCharacterScreen> createState() => _ChooseDifferentCharacterScreenState();
}

class _ChooseDifferentCharacterScreenState extends State<ChooseDifferentCharacterScreen> {
  final _apiService = ApiService();
  late Future<List<Character>> _charactersFuture;
  String? _selectedId;
  bool _isSubmitting = false;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    _charactersFuture = _apiService.getAllCharactersForUser();
  }

  Future<void> _swap() async {
    if (_selectedId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.copyCharactersToBook(
        bookId: widget.bookId,
        characterIds: [_selectedId!],
      );
      await _apiService.deleteCharacter(characterId: widget.currentCharacterId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to swap: $e')),
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
          title: const Text('Choose Different Character'),
          actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
        ),
      body: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final characters = (snapshot.data ?? [])
              .where((c) => c.id != widget.currentCharacterId)
              .toList();

          if (characters.isEmpty) {
            return Center(
              child: Text(
                'No other characters yet. Go to Characters > New Character to make one first.',
                style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
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
              final isSelected = _selectedId == character.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedId = character.id;
                  });
                },
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
                  onPressed: (_selectedId == null || _isSubmitting) ? null : _swap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedId != null ? Colors.green : null,
                    foregroundColor: _selectedId != null ? Colors.white : null,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Swap Character', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            const DebugScreenTag('choose_different_character_screen.dart'),
          ],
        ),
      ),
      ),
    );
  }
}
