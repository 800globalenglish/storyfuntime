import 'package:flutter/material.dart';
import 'avatar_gallery_screen.dart';
import 'choose_different_character_screen.dart';
import 'character_picker_screen.dart';
import 'apply_template_screen.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'creator_wizard_screen.dart';
import 'record_story_screen.dart';
import '../utils/fade_route.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

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
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
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
      FadeRoute(page: CharacterPickerScreen(bookId: widget.bookId)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _goToApplyTemplate() async {
    await Navigator.push(
      context,
      FadeRoute(page: ApplyTemplateScreen(bookId: widget.bookId)),
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
      setState(() => _generateError = AppStrings.t('please_fill_title_theme'));
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
      setState(() => _generateError = '${AppStrings.t('failed_to_generate_story')} $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showRenameDialog(Book book) async {
    final titleController = TextEditingController(text: book.title);
    final themeController = TextEditingController(text: book.theme);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Story'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: themeController,
              decoration: const InputDecoration(labelText: 'Theme'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newTitle = titleController.text.trim();
      final newTheme = themeController.text.trim();
      if (newTitle.isEmpty || newTheme.isEmpty) return;

      try {
        await _apiService.updateBook(bookId: widget.bookId, title: newTitle, theme: newTheme);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename: $e')),
          );
        }
      }
    }

    titleController.dispose();
    themeController.dispose();
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
            : Text(AppStrings.t('what_would_you_like_to_do')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(AppStrings.t('done')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'regenerate'),
            child: Text(AppStrings.t('regenerate_character')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: Text(AppStrings.t('view_characters')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'swap'),
            child: Text(AppStrings.t('choose_different')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(AppStrings.t('delete'), style: const TextStyle(color: Colors.red)),
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
          title: Text(AppStrings.t('regenerate_character')),
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
                decoration: InputDecoration(
                  labelText: AppStrings.t('optional_instructions'),
                  hintText: AppStrings.t('regenerate_character_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.t('regenerate')),
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
              SnackBar(content: Text('${AppStrings.t('failed_to_regenerate')} $e')),
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
        FadeRoute(
          page: AvatarGalleryScreen(
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
        FadeRoute(
          page: ChooseDifferentCharacterScreen(
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
            SnackBar(content: Text('${AppStrings.t('failed_to_delete')} $e')),
          );
        }
      }
    }
  }

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Book>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            bottomNavigationBar: const DebugScreenTag('book_detail_screen.dart'),
            appBar: AppBar(
              centerTitle: true,
              title: Text(AppStrings.t('book_details_title')),
              actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            bottomNavigationBar: const DebugScreenTag('book_detail_screen.dart'),
            appBar: AppBar(
              centerTitle: true,
              title: Text(AppStrings.t('book_details_title')),
              actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
            ),
            body: Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}')),
          );
        }
        final book = snapshot.data!;
        if (!_formFieldsInitialized) {
          _titleController.text = book.title == 'My Story' ? '' : book.title;
          _themeController.text = book.theme == 'draft' ? '' : book.theme;
          _formFieldsInitialized = true;
        }
        return Scaffold(
          bottomNavigationBar: const DebugScreenTag('book_detail_screen.dart'),
          appBar: AppBar(
            centerTitle: true,
            toolbarHeight: 76,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(book.title, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                Text(book.status, style: const TextStyle(fontSize: 13)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Rename',
                onPressed: () => _showRenameDialog(book),
              ),
              const AppNavMenuButton(),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t('characters_title'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: book.characters.length + 1,
                  itemBuilder: (context, index) {
                    if (index == book.characters.length) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _goToAddCharacter,
                            icon: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 4),
                          Text(AppStrings.t('add'), style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }
                    final character = book.characters[index];
                    return GestureDetector(
                      onTap: () => _showCharacterOptions(character.id, character.name, character.cartoonAvatarUrl, book.userId),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: _buttonRadius,
                                  child: character.cartoonAvatarUrl != null
                                      ? Image.network(
                                    '${ApiService.baseUrl}${character.cartoonAvatarUrl}?v=${DateTime.now().millisecondsSinceEpoch}',
                                    fit: BoxFit.cover,
                                  )
                                      : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.person, size: 80),
                                  ),
                                ),
                                if (_regeneratingAvatarCharacterId == character.id)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: _buttonRadius,
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
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: _buttonHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ElevatedButton.icon(
                          onPressed: _showGenerateForm
                              ? null
                              : () => setState(() => _showGenerateForm = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.blue,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 32),
                          label: Text(
                            AppStrings.t('generate_story'),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      if (_showGenerateForm)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                            tooltip: 'Back',
                            onPressed: () => setState(() => _showGenerateForm = false),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_showGenerateForm) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _goToApplyTemplate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      icon: const Icon(Icons.auto_stories, size: 32),
                      label: Text(
                        AppStrings.t('story_templates'),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          FadeRoute(page: RecordStoryScreen(bookId: widget.bookId)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      icon: const Icon(Icons.mic, size: 32),
                      label: const Text(
                        'Record Your Story',
                        style: TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ],
                if (_showGenerateForm) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                    decoration: InputDecoration(
                      labelText: AppStrings.t('book_title_label'),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      border: OutlineInputBorder(borderRadius: _buttonRadius),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppStrings.t('num_scenes_label'), style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _sceneCount,
                        style: const TextStyle(fontSize: 22, color: Colors.black),
                        items: [
                          for (int i = 1; i <= 10; i++)
                            DropdownMenuItem(value: i, child: Text('$i', style: const TextStyle(fontSize: 22))),
                        ],
                        onChanged: _isGenerating ? null : (value) => setState(() => _sceneCount = value ?? 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _themeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                    decoration: InputDecoration(
                      labelText: AppStrings.t('theme_label'),
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      border: OutlineInputBorder(borderRadius: _buttonRadius),
                    ),
                  ),
                  if (_generateError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _generateError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 22),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateStory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGenerating ? Colors.green.shade800 : Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade800,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.auto_awesome, size: 28),
                      label: Text(AppStrings.t('generate'), style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
