import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _charactersFuture = _apiService.getAllCharactersForUser(userId: 'test-user-1');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Different Character')),
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
            return const Center(
              child: Text('No other characters yet. Go to Characters > New Character to make one first.'),
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
            onPressed: (_selectedId == null || _isSubmitting) ? null : _swap,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Swap Character'),
          ),
        ),
      ),
    );
  }
}
