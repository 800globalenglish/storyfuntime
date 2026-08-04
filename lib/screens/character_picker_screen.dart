import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'book_detail_screen.dart';

// NEW - one entry per unique avatar. If the same person appears in several
// books, count reflects how many, and representative is whichever Character
// record we show/select (any of them clones the same name/avatar into the
// target book via copyCharactersToBook, so it doesn't matter which one).
class _CharacterGroup {
  final Character representative;
  final int count;

  _CharacterGroup({required this.representative, required this.count});
}

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

  // NEW - groups characters that share the same cartoon avatar (same person,
  // reused across multiple books). Characters with no avatar yet are never
  // grouped together with each other.
  List<_CharacterGroup> _groupCharacters(List<Character> characters) {
    final Map<String, List<Character>> groups = {};
    for (final c in characters) {
      final key = c.cartoonAvatarUrl ?? 'ungrouped-${c.id}';
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups.values
        .map((group) => _CharacterGroup(representative: group.first, count: group.length))
        .toList();
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
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('choose_characters_title'))),
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
              child: Text(AppStrings.t('no_characters_yet_hint')),
            );
          }

          final groups = _groupCharacters(characters);

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
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
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'In ${group.count} stories',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(character.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _next,
            child: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text('${AppStrings.t('next_selected_prefix')} (${_selectedIds.length} ${AppStrings.t('selected_suffix')})'),
          ),
        ),
      ),
    );
  }
}