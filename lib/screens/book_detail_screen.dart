import 'package:flutter/material.dart';
import 'avatar_gallery_screen.dart';
import 'choose_different_character_screen.dart';
import 'character_picker_screen.dart';
import 'apply_template_screen.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'creator_wizard_screen.dart';

/// Screen 1 of the book flow: setup. Shown for a book that has no pages
/// yet. Lets the person add characters, then either generate a story
/// (inline form right here, no separate screen) or apply a story
/// template. Either path hands off to CreatorWizardScreen once pages exist.
class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;
  String? _regeneratingAvatarCharacterId;

  final Map<String, String> _lastAvatarInstructions = {};

  bool _showGenerateForm = false;
  bool _formFieldsInitialized = false;
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  int _sceneCount = 5;
  bool _isGenerating = false;
  String? _generateError;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  void _loadBook() {
    _bookFuture = _apiService.getBook(id: widget.bookId);
  }

  void _refresh() {
    setState(() {
      _loadBook();
      _formFieldsInitialized = false;
    });
  }

  Future<void> _goToAddCharacter() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CharacterPickerScreen(bookId: widget.bookId)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _goToApplyTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ApplyTemplateScreen(bookId: widget.bookId)),
    );
    if (!mounted) return;

    final updatedBook = await _apiService.getBook(id: widget.bookId);
    if (!mounted) return;

    if (updatedBook.pages.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CreatorWizardScreen(bookId: widget.bookId)),
      );
    } else {
      _refresh();
    }
  }

  Future<void> _generateStory() async {
    if (_titleController.text.trim().isEmpty || _themeController.text.trim().isEmpty) {
      setState(() => _generateError = 'Please fill in both the title and theme.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generateError = null;
    });

    try {
      await _apiService.updateBook(
        bookId: widget.bookId,
        title: _titleController.text.trim(),
        theme: _themeController.text.trim(),
      );

      final pages = await _apiService.generateScript(bookId: widget.bookId, pageCount: _sceneCount);
      for (int i = 0; i < pages.length; i++) {
        await _apiService.addPage(
          bookId: widget.bookId,
          pageNumber: i + 1,
          scriptText: pages[i],
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreatorWizardScreen(bookId: widget.bookId)),
        );
      }
    } catch (e) {
      setState(() => _generateError = 'Failed to generate story: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showCharacterOptions(String characterId, String name, String? cartoonAvatarUrl, String userId, {String? currentAvatarUrl}) async {
    final bookId = widget.bookId;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: cartoonAvatarUrl != null
            ? SizedBox(
          width: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network('${ApiService.baseUrl}$cartoonAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}'),
          ),
        )
            : const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'regenerate'),
            child: const Text('Regenerate Character'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: const Text('View Characters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'swap'),
            child: const Text('Choose Different'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'regenerate') {
      final instructionsController = TextEditingController(text: _lastAvatarInstructions[characterId] ?? '');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Regenerate Character'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cartoonAvatarUrl != null) ...[
                SizedBox(
                  width: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '${ApiService.baseUrl}$cartoonAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: instructionsController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional instructions',
                  hintText: 'e.g. make the hair darker, add glasses',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );

      if (proceed == true) {
        _lastAvatarInstructions[characterId] = instructionsController.text.trim();
        setState(() {
          _regeneratingAvatarCharacterId = characterId;
        });

        try {
          final updatedCharacter = await _apiService.regenerateCharacterAvatar(
            characterId: characterId,
            extraInstructions: instructionsController.text.trim().isEmpty
                ? null
                : instructionsController.text.trim(),
          );

          _refresh();
          setState(() {
            _regeneratingAvatarCharacterId = null;
          });
          if (mounted) {
            await _showCharacterOptions(characterId, name, updatedCharacter.cartoonAvatarUrl, userId);
          }
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to regenerate: $e')),
            );
          }
        } finally {
          setState(() {
            _regeneratingAvatarCharacterId = null;
          });
        }
      }
    } else if (action == 'gallery') {
      final selected = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AvatarGalleryScreen(
            characterId: characterId,
            characterName: name,
            currentAvatarUrl: currentAvatarUrl ?? cartoonAvatarUrl,
            bookId: bookId,
          ),
        ),
      );
      if (selected == true) {
        _refresh();
      }
    } else if (action == 'swap') {
      final swapped = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ChooseDifferentCharacterScreen(
            bookId: bookId,
            currentCharacterId: characterId,
          ),
        ),
      );
      if (swapped == true) {
        _refresh();
      }
    } else if (action == 'delete') {
      try {
        await _apiService.deleteCharacter(characterId: characterId);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Details')),
      body: FutureBuilder<Book>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final book = snapshot.data!;
          if (!_formFieldsInitialized) {
            _titleController.text = book.title == 'My Story' ? '' : book.title;
            _themeController.text = book.theme == 'draft' ? '' : book.theme;
            _formFieldsInitialized = true;
          }
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${book.theme} - ${book.status}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('Characters', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final character in book.characters)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _showCharacterOptions(character.id, character.name, character.cartoonAvatarUrl, book.userId),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: character.cartoonAvatarUrl != null
                                            ? Image.network(
                                          '${ApiService.baseUrl}${character.cartoonAvatarUrl}?v=${DateTime.now().millisecondsSinceEpoch}',
                                          fit: BoxFit.cover,
                                        )
                                            : Container(
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.person, size: 40),
                                        ),
                                      ),
                                      if (_regeneratingAvatarCharacterId == character.id)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black45,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(character.name, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _goToAddCharacter,
                            icon: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 4),
                          const Text('Add', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showGenerateForm
                            ? null
                            : () => setState(() => _showGenerateForm = true),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate Story'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _goToApplyTemplate,
                        icon: const Icon(Icons.auto_stories),
                        label: const Text('Story Templates'),
                      ),
                    ),
                  ],
                ),
                if (_showGenerateForm) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Book Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('# Scenes'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _sceneCount,
                        items: [for (int i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                        onChanged: _isGenerating ? null : (value) => setState(() => _sceneCount = value ?? 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _themeController,
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_generateError != null) ...[
                    const SizedBox(height: 8),
                    Text(_generateError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isGenerating ? null : _generateStory,
                    child: _isGenerating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Generate'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
