import 'package:flutter/material.dart';
import 'avatar_gallery_screen.dart';
import 'choose_different_character_screen.dart';
import 'character_picker_screen.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'generate_story_screen.dart';
import 'record_voice_screen.dart';
import 'book_reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;
  String? _generatingScenePageId;

  String? _regeneratingTextPageId;

  String? _regeneratingAvatarCharacterId;

  final Map<String, String> _lastAvatarInstructions = {};

  final Map<String, String> _lastSceneInstructions = {};

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

  Future<void> _goToGenerateStory() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GenerateStoryScreen(bookId: widget.bookId)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _goToRecordVoice(String pageId, int pageNumber, String scriptText) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordVoiceScreen(
          pageId: pageId,
          pageNumber: pageNumber,
          scriptText: scriptText,
        ),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _goToAddCharacter() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CharacterPickerScreen(bookId: widget.bookId)),
    );
    if (saved == true) _refresh();
  }

  void _goToReadBook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookReaderScreen(bookId: widget.bookId)),
    );
  }

  Future<void> _editPageText(String pageId, String currentText) async {
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Page Text'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      try {
        await _apiService.updatePageText(pageId: pageId, scriptText: newText);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e')),
          );
        }
      }
    }
  }

  Future<void> _regeneratePageText(String pageId) async {
    setState(() {
      _regeneratingTextPageId = pageId;
    });
    try {
      await _apiService.regeneratePageText(pageId: pageId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate text: $e')),
        );
      }
    } finally {
      setState(() {
        _regeneratingTextPageId = null;
      });
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
            child: Image.network('http://localhost:5220$cartoonAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}'),
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
                      'http://localhost:5220$cartoonAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}',
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
        debugPrint('[Regenerate] Button tapped for characterId=$characterId'); // LOG 1

        _lastAvatarInstructions[characterId] = instructionsController.text.trim();
        setState(() {
          _regeneratingAvatarCharacterId = characterId;
        });

        // Immediate feedback so we know the tap registered at all
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Regenerating character...'), duration: Duration(seconds: 2)),
          );
        }

        try {
          debugPrint('[Regenerate] Calling API...'); // LOG 2
          final updatedCharacter = await _apiService.regenerateCharacterAvatar(
            characterId: characterId,
            extraInstructions: instructionsController.text.trim().isEmpty
                ? null
                : instructionsController.text.trim(),
          );
          debugPrint('[Regenerate] API returned. New cartoonAvatarUrl=${updatedCharacter.cartoonAvatarUrl}'); // LOG 3

          _refresh();
          setState(() {
            _regeneratingAvatarCharacterId = null;
          });
          if (mounted) {
            await _showCharacterOptions(characterId, name, updatedCharacter.cartoonAvatarUrl, userId);
          }
          return;
        } catch (e) {
          debugPrint('[Regenerate] ERROR: $e'); // LOG 4
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
            userId: userId,
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

  void _viewScene(String cartoonImageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Image.network(
              'http://localhost:5220$cartoonImageUrl?v=${DateTime.now().millisecondsSinceEpoch}',
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revertScene(String pageId) async {
    try {
      await _apiService.revertScene(pageId: pageId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revert: $e')),
        );
      }
    }
  }

  Future<void> _generateScene(String pageId, String? currentSceneUrl) async {
    final instructionsController = TextEditingController(text: _lastSceneInstructions[pageId] ?? '');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Scene'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentSceneUrl != null) ...[
              SizedBox(
                width: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'http://localhost:5220$currentSceneUrl?v=${DateTime.now().millisecondsSinceEpoch}',
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
                hintText: 'e.g. add a hat, make it daytime',
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
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    _lastSceneInstructions[pageId] = instructionsController.text.trim();

    setState(() {
      _generatingScenePageId = pageId;
    });
    try {
      await _apiService.generateScene(
        pageId: pageId,
        extraInstructions: instructionsController.text.trim().isEmpty
            ? null
            : instructionsController.text.trim(),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scene generation failed: $e')),
        );
      }
    } finally {
      setState(() {
        _generatingScenePageId = null;
      });
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
                  height: 90,
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
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: character.cartoonAvatarUrl != null
                                          ? NetworkImage('http://localhost:5220${character.cartoonAvatarUrl}?v=${DateTime.now().millisecondsSinceEpoch}')
                                          : null,
                                      child: character.cartoonAvatarUrl == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    if (_regeneratingAvatarCharacterId == character.id)
                                      Positioned.fill(
                                        child: CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.black45,
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _goToGenerateStory,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate Story'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _goToReadBook,
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Read Book'),
                ),
                const SizedBox(height: 24),
                Text('Pages', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: book.pages.isEmpty
                      ? const Text('No pages yet.')
                      : ListView.builder(
                          itemCount: book.pages.length,
                          itemBuilder: (context, index) {
                            final page = book.pages[index];
                            final hasAudio = page.audioUrl != null;
                            final hasScene = page.cartoonImageUrl != null;
                            final isGeneratingThisScene = _generatingScenePageId == page.id;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(child: Text('${page.pageNumber}')),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(page.scriptText)),
                                        _regeneratingTextPageId == page.id
                                            ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                            : PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _editPageText(page.id, page.scriptText);
                                            } else if (value == 'regenerate') {
                                              _regeneratePageText(page.id);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Text('Edit text')),
                                            const PopupMenuItem(value: 'regenerate', child: Text('Regenerate text')),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _goToRecordVoice(page.id, page.pageNumber, page.scriptText),
                                          icon: Icon(
                                            hasAudio ? Icons.check_circle : Icons.mic_none,
                                            color: hasAudio ? Colors.green : null,
                                          ),
                                          label: Text(hasAudio ? 'Voice recorded' : 'Record voice'),
                                        ),
                                        const SizedBox(width: 8),
                                        isGeneratingThisScene
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : TextButton.icon(
                                          onPressed: book.characters.isEmpty
                                              ? null
                                              : () => _generateScene(page.id, page.cartoonImageUrl),
                                                icon: Icon(
                                                  hasScene ? Icons.check_circle : Icons.auto_fix_high,
                                                  color: hasScene ? Colors.green : null,
                                                ),
                                          label: Text(hasScene ? 'Scene made' : 'Generate scene'),
                                        ),
                                        if (hasScene)
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined),
                                            tooltip: 'View scene',
                                            onPressed: () => _viewScene(page.cartoonImageUrl!),
                                          ),
                                        if (page.previousCartoonImageUrl != null)
                                          IconButton(
                                            icon: const Icon(Icons.undo),
                                            tooltip: 'Revert to previous scene',
                                            onPressed: () => _revertScene(page.id),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
