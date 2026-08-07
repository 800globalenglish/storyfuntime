import 'package:flutter/material.dart';
import 'choose_different_character_screen.dart';
import 'character_picker_screen.dart';
import 'apply_template_screen.dart';
import '../models/book.dart';
import '../models/story_type.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'creator_wizard_screen.dart';
import 'record_story_screen.dart';
import '../utils/fade_route.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../widgets/voice_text_field.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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
  StoryType _selectedStoryType = StoryType.bedtime;
  bool _isGenerating = false;
  String? _generateError;
  bool _showTextForm = false;
  final _userTextController = TextEditingController();
  bool _isGeneratingFromText = false;
  String? _textGenerateError;
  static const _storyTextMaxLength = 5000;
  static const _storyTextWarningThreshold = 200;
  bool _exactText = false;
  int? _selectedPageCount;

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
    _userTextController.dispose();
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

      final pages = await _apiService.generateScript(
        bookId: widget.bookId,
        pageCount: _sceneCount,
        storyType: _selectedStoryType.apiValue,
      );
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

  int _wordCountOf(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  int _minPagesForWordCount(int wordCount) => wordCount <= 0 ? 1 : (wordCount / 75).ceil();
  int _maxPagesForWordCount(int wordCount) => wordCount <= 0 ? 1 : (wordCount / 25).ceil();

  Future<void> _generateStoryFromText() async {
    if (_userTextController.text.trim().isEmpty) {
      setState(() => _textGenerateError = AppStrings.t('please_enter_story_text'));
      return;
    }

    setState(() {
      _isGeneratingFromText = true;
      _textGenerateError = null;
    });

    try {
      final wordCount = _wordCountOf(_userTextController.text);
      final minPages = _minPagesForWordCount(wordCount);
      final maxPages = _maxPagesForWordCount(wordCount);
      final pageCount = (_selectedPageCount ?? ((minPages + maxPages) / 2).round()).clamp(minPages, maxPages);
      final pages = await _apiService.generateScriptFromText(
        bookId: widget.bookId,
        userText: _userTextController.text.trim(),
        exactText: _exactText,
        pageCount: pageCount,
      );
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
      setState(() => _textGenerateError = '${AppStrings.t('failed_to_generate_story')} $e');
    } finally {
      if (mounted) setState(() => _isGeneratingFromText = false);
    }
  }

  Future<void> _showRenameDialog(Book book) async {
    final titleController = TextEditingController(text: book.title);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Story'),
        content: VoiceTextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (saved == true) {
      final newTitle = titleController.text.trim();
      if (newTitle.isEmpty) return;

      try {
        await _apiService.updateBook(bookId: widget.bookId, title: newTitle, theme: book.theme);
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
  }

  Future<void> _showRenameCharacterDialog(String characterId, String currentName) async {
    final nameController = TextEditingController(text: currentName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Character'),
        content: VoiceTextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (saved == true) {
      final newName = nameController.text.trim();
      if (newName.isEmpty) return;

      try {
        await _apiService.renameCharacter(characterId: characterId, name: newName);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename: $e')),
          );
        }
      }
    }

    nameController.dispose();
  }

  Future<void> _showCharacterOptions(String characterId, String name, String? cartoonAvatarUrl, String userId) async {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: _buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'swap'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                        foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      child: Text(AppStrings.t('replace'), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: _buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'regenerate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                        foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      child: Text(AppStrings.t('regenerate'), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: _buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      child: Text(AppStrings.t('remove'), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: _buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      child: Text(AppStrings.t('close'), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ],
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
              VoiceTextField(
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
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => FutureBuilder<Book>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: ThemeController.instance.backgroundData.color,
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
            backgroundColor: ThemeController.instance.backgroundData.color,
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
          backgroundColor: ThemeController.instance.backgroundData.color,
          bottomNavigationBar: const DebugScreenTag('book_detail_screen.dart'),
          appBar: AppBar(
            centerTitle: true,
            title: Text(book.title, style: const TextStyle(fontSize: 22)),
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
                Text(
                  AppStrings.t('characters_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ThemeController.instance.backgroundData.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: book.characters.length + 1,
                  itemBuilder: (context, index) {
                    // The Add tile stays pinned in the first row (3rd column)
                    // as long as there's room for it - once a 3rd character
                    // exists, it drops to the next row instead of pushing
                    // Add out of sight.
                    final addIndex = book.characters.length >= 2 ? 2 : book.characters.length;
                    if (index == addIndex) {
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
                    final characterIndex = index < addIndex ? index : index - 1;
                    final character = book.characters[characterIndex];
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  character.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ThemeController.instance.backgroundData.bodyTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _showRenameCharacterDialog(character.id, character.name),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: ThemeController.instance.backgroundData.bodyTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (!_showTextForm) ...[
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ElevatedButton.icon(
                            onPressed: _showGenerateForm ? null : () => setState(() => _showGenerateForm = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeController.instance.buttonColor(ButtonRole.primary),
                              foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.primary),
                              disabledBackgroundColor: ThemeController.instance.buttonColor(ButtonRole.primary),
                              disabledForegroundColor: ThemeController.instance.buttonTextColor(ButtonRole.primary),
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
                              icon: Icon(Icons.arrow_back, color: ThemeController.instance.buttonTextColor(ButtonRole.primary), size: 32),
                              tooltip: 'Back',
                              onPressed: () => setState(() => _showGenerateForm = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!_showGenerateForm && !_showTextForm) const SizedBox(height: 16),
                if (!_showGenerateForm) ...[
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ElevatedButton.icon(
                            onPressed: _showTextForm ? null : () => setState(() => _showTextForm = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                              foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                              disabledBackgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                              disabledForegroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                              shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                            ),
                            icon: const Icon(Icons.text_snippet, size: 32),
                            label: Text(
                              AppStrings.t('story_from_text_button'),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        if (_showTextForm)
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back, color: ThemeController.instance.buttonTextColor(ButtonRole.accent), size: 32),
                              tooltip: 'Back',
                              onPressed: () => setState(() => _showTextForm = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!_showGenerateForm && !_showTextForm) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _goToApplyTemplate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                        foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('story_type_label'),
                              style: TextStyle(fontSize: 13, color: ThemeController.instance.backgroundData.bodyTextColor),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<StoryType>(
                              value: _selectedStoryType,
                              style: const TextStyle(fontSize: 18, color: Colors.black),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: _buttonRadius),
                                isDense: true,
                              ),
                              items: [
                                for (final type in StoryType.values)
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(type.label, style: const TextStyle(fontSize: 16)),
                                  ),
                              ],
                              onChanged: _isGenerating
                                  ? null
                                  : (value) => setState(() => _selectedStoryType = value ?? StoryType.bedtime),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.t('num_scenes_label'),
                        style: TextStyle(fontSize: 18, color: ThemeController.instance.backgroundData.bodyTextColor),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: _buttonRadius,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: DropdownButton<int>(
                          value: _sceneCount,
                          underline: const SizedBox(),
                          style: const TextStyle(fontSize: 18, color: Colors.black),
                          items: [
                            for (int i = 1; i <= 10; i++)
                              DropdownMenuItem(value: i, child: Text('$i', style: const TextStyle(fontSize: 18))),
                          ],
                          onChanged: _isGenerating ? null : (value) => setState(() => _sceneCount = value ?? 5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  VoiceTextField(
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
                  VoiceTextField(
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
                if (_showTextForm) ...[
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(AppStrings.t('exact_text_mode'))),
                      ButtonSegment(value: false, label: Text(AppStrings.t('ai_magic_mode'))),
                    ],
                    selected: {_exactText},
                    onSelectionChanged: (selection) => setState(() => _exactText = selection.first),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _userTextController,
                    builder: (context, child) {
                      final storyTextRemaining = _storyTextMaxLength - _userTextController.text.length;
                      final storyTextNearLimit = storyTextRemaining <= _storyTextWarningThreshold;
                      final storyTextWarningColor = storyTextRemaining <= 0 ? Colors.red : Colors.orange;
                      final wordCount = _wordCountOf(_userTextController.text);
                      final minPages = _minPagesForWordCount(wordCount);
                      final maxPages = _maxPagesForWordCount(wordCount);
                      final showPagePicker = wordCount > 0;
                      final pageCount = (_selectedPageCount ?? ((minPages + maxPages) / 2).round()).clamp(minPages, maxPages);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VoiceTextField(
                            controller: _userTextController,
                            maxLines: 8,
                            maxLength: _storyTextMaxLength,
                            decoration: InputDecoration(
                              labelText: AppStrings.t('your_story_label'),
                              hintText: AppStrings.t('paste_or_type_story_hint'),
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                              counterStyle: storyTextNearLimit ? TextStyle(color: storyTextWarningColor) : null,
                            ),
                          ),
                          if (storyTextNearLimit) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.t('approaching_character_limit').replaceFirst('{remaining}', '$storyTextRemaining'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: storyTextWarningColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                          if (showPagePicker) ...[
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.t('potential_pages_label')
                                  .replaceFirst('{min}', '$minPages')
                                  .replaceFirst('{max}', '$maxPages'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ThemeController.instance.backgroundData.bodyTextColor),
                            ),
                            if (maxPages > minPages)
                              Slider(
                                value: pageCount.toDouble(),
                                min: minPages.toDouble(),
                                max: maxPages.toDouble(),
                                divisions: maxPages - minPages,
                                label: '$pageCount',
                                onChanged: (value) => setState(() => _selectedPageCount = value.round()),
                              ),
                            Text(
                              '$pageCount',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeController.instance.backgroundData.bodyTextColor),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  if (_textGenerateError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _textGenerateError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingFromText ? null : _generateStoryFromText,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                        foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      icon: _isGeneratingFromText
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.auto_awesome, size: 32),
                      label: Text(AppStrings.t('generate'), style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
                ],
              ),
          ),
        );
      },
    ),
    );
  }
}
