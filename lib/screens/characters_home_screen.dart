import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import 'add_character_screen.dart';
import 'create_book_screen.dart';

class CharactersHomeScreen extends StatefulWidget {
  const CharactersHomeScreen({super.key});

  @override
  State<CharactersHomeScreen> createState() => _CharactersHomeScreenState();
}

class _CharactersHomeScreenState extends State<CharactersHomeScreen> {
  final _apiService = ApiService();
  late Future<List<Character>> _charactersFuture;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  void _loadCharacters() {
    _charactersFuture = _apiService.getAllCharactersForUser(userId: 'test-user-1');
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
      final libraryBookId = await _apiService.getLibraryBookId(userId: 'test-user-1');
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddCharacterScreen(bookId: libraryBookId)),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e')),
        );
      }
    }
  }

  Future<void> _goToNewBook() async {
    if (_selectedIds.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create book without characters?'),
          content: const Text('You haven\'t selected any characters. You can add them later, or go back and pick some now.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBookScreen(preSelectedCharacterIds: _selectedIds.toList()),
      ),
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
        title: Text('Delete $name?'),
        content: const Text('This removes them entirely, including from any books they\'re in. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Characters')),
      body: FutureBuilder<List<Character>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final characters = snapshot.data ?? [];
          if (characters.isEmpty) {
            return const Center(
              child: Text('No characters yet. Tap "Take Photo" to make your first one!'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final character = characters[index];
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
                                    'http://localhost:5220${character.cartoonAvatarUrl}',
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('New Character'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToNewBook,
            style: _selectedIds.isNotEmpty
                ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)
                : null,
                  icon: const Icon(Icons.auto_stories),
                  label: Text('New Book (${_selectedIds.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
