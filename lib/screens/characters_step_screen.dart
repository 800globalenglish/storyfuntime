import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'add_character_screen.dart';
import 'generate_story_screen.dart';

class CharactersStepScreen extends StatefulWidget {
  final String bookId;

  const CharactersStepScreen({super.key, required this.bookId});

  @override
  State<CharactersStepScreen> createState() => _CharactersStepScreenState();
}

class _CharactersStepScreenState extends State<CharactersStepScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  void _loadBook() {
    _bookFuture = _apiService.getBook(id: widget.bookId);
  }

  void _refresh() {
    setState(() {
      _loadBook();
    });
  }

  Future<void> _goToAddCharacter() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCharacterScreen(bookId: widget.bookId)),
    );
    if (saved == true) _refresh();
  }

  void _goToStory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateStoryScreen(bookId: widget.bookId, isWizard: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 3: Add Characters')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add the people (and pets!) who will appear in this story.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<Book>(
                future: _bookFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final characters = snapshot.data!.characters;
                  return GridView.count(
                    crossAxisCount: 3,
                    children: [
                      for (final character in characters)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: character.cartoonAvatarUrl != null
                                  ? NetworkImage('http://localhost:5220${character.cartoonAvatarUrl}?v=${DateTime.now().millisecondsSinceEpoch}')
                                  : null,
                              child: character.cartoonAvatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(character.name),
                          ],
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            iconSize: 32,
                            onPressed: _goToAddCharacter,
                            icon: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 4),
                          const Text('Add'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _goToStory,
              child: const Text('Next: Write the Story'),
            ),
          ],
        ),
      ),
    );
  }
}
