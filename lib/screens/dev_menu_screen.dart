import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/book_page.dart';
import '../models/character.dart';
import '../models/story_template.dart';
import '../services/api_service.dart';
import '../utils/fade_route.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'stories_list_screen.dart';
import 'characters_home_screen.dart';
import 'create_book_screen.dart';
import 'add_character_screen.dart';
import 'book_detail_screen.dart';
import 'book_summary_screen.dart';
import 'creator_wizard_screen.dart';
import 'book_reader_screen.dart';
import 'record_story_screen.dart';
import 'apply_template_screen.dart';
import 'character_picker_screen.dart';
import 'choose_different_character_screen.dart';
import 'avatar_gallery_screen.dart';
import 'record_voice_screen.dart';
import 'upload_photo_screen.dart';
import 'template_admin_screen.dart';
import 'template_page_editor_screen.dart';
import 'video_player_screen.dart';
import 'credits_screen.dart';
import 'my_invites_screen.dart';
import 'language_settings_screen.dart';
import 'theme_picker_screen.dart';

/// TEMPORARY dev-only screen. Reachable at http://localhost:8765/#/debug so
/// you can jump straight to any screen while testing, instead of clicking
/// through the whole app every time. Auto-fills real bookId/pageId/
/// characterId from your account's existing data where a screen needs one.
/// Not meant to ship - remove the /debug route in main.dart (and this file)
/// once you're done with it.
class DevMenuScreen extends StatefulWidget {
  const DevMenuScreen({super.key});

  @override
  State<DevMenuScreen> createState() => _DevMenuScreenState();
}

class _DevMenuScreenState extends State<DevMenuScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  Book? _anyBook;
  Book? _bookWithPages;
  Book? _bookWithVideo;
  BookPage? _testPage;
  Character? _testCharacter;
  StoryTemplate? _testTemplate;
  final Set<String> _verifiedFiles = {}; // TEMP - lets you check off pages as you test them
  static const _verifiedFilesPrefsKey = 'dev_menu_verified_files';
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVerifiedFiles();
  }

  Future<void> _loadVerifiedFiles() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs!.getStringList(_verifiedFilesPrefsKey) ?? [];
    if (mounted) setState(() => _verifiedFiles.addAll(saved));
  }

  void _toggleVerified(String fileName, bool checked) {
    setState(() {
      if (checked) {
        _verifiedFiles.add(fileName);
      } else {
        _verifiedFiles.remove(fileName);
      }
    });
    _prefs?.setStringList(_verifiedFilesPrefsKey, _verifiedFiles.toList());
  }

  Future<void> _load() async {
    try {
      final books = await _apiService.getBooks();
      final characters = await _apiService.getAllCharactersForUser();
      List<StoryTemplate> templates = [];
      try {
        templates = await _apiService.getStoryTemplates();
      } catch (_) {
        // Templates are optional for this menu - not every account has any.
      }

      Book? bookWithPages;
      BookPage? page;
      for (final b in books) {
        if (b.pages.isNotEmpty) {
          bookWithPages = b;
          page = b.pages.first;
          break;
        }
      }

      Book? bookWithVideo;
      for (final b in books) {
        if (b.videoUrl != null) {
          bookWithVideo = b;
          break;
        }
      }

      setState(() {
        _anyBook = books.isNotEmpty ? books.first : null;
        _bookWithPages = bookWithPages;
        _testPage = page;
        _bookWithVideo = bookWithVideo;
        _testCharacter = characters.isNotEmpty ? characters.first : null;
        _testTemplate = templates.isNotEmpty ? templates.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load test data: $e';
        _isLoading = false;
      });
    }
  }

  void _goTo(Widget screen) {
    Navigator.push(context, FadeRoute(page: screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Menu (temporary)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!)))
              : ListView(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.yellow.shade100,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Test data in use:\n'
                        'book = ${_anyBook?.title ?? "none found"}\n'
                        'book with pages = ${_bookWithPages?.title ?? "none found"}\n'
                        'book with video = ${_bookWithVideo?.title ?? "none found"}\n'
                        'character = ${_testCharacter?.name ?? "none found"}\n'
                        'template = ${_testTemplate?.title ?? "none found"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _section('No data needed'),
                    _tile('Characters Home', 'characters_home_screen.dart', () => _goTo(const CharactersHomeScreen())),
                    _tile('Create Book', 'create_book_screen.dart', () => _goTo(const CreateBookScreen())),
                    _tile('Buy Credits', 'credits_screen.dart', () => _goTo(const CreditsScreen())),
                    _tile('Home', 'home_screen.dart', () => _goTo(const HomeScreen())),
                    _tile('Language Settings', 'language_settings_screen.dart', () => _goTo(const LanguageSettingsScreen())),
                    _tile('Login', 'login_screen.dart', () => _goTo(const LoginScreen())),
                    _tile('My Invites', 'my_invites_screen.dart', () => _goTo(const MyInvitesScreen())),
                    _tile('My Stories', 'stories_list_screen.dart', () => _goTo(const StoriesListScreen())),
                    _tile('Manage Story Templates', 'template_admin_screen.dart', () => _goTo(const TemplateAdminScreen())),
                    _tile('Theme Picker', 'theme_picker_screen.dart', () => _goTo(const ThemePickerScreen())),
                    _section('Needs a book (bookId)'),
                    _tile('Add Character', 'add_character_screen.dart', _anyBook == null ? null : () => _goTo(AddCharacterScreen(bookId: _anyBook!.id))),
                    _tile('Apply Template', 'apply_template_screen.dart', _anyBook == null ? null : () => _goTo(ApplyTemplateScreen(bookId: _anyBook!.id))),
                    _tile('Book Detail', 'book_detail_screen.dart', _anyBook == null ? null : () => _goTo(BookDetailScreen(bookId: _anyBook!.id))),
                    _tile('Book Reader', 'book_reader_screen.dart', _anyBook == null ? null : () => _goTo(BookReaderScreen(bookId: _anyBook!.id))),
                    _tile('Book Summary', 'book_summary_screen.dart', _anyBook == null ? null : () => _goTo(BookSummaryScreen(bookId: _anyBook!.id))),
                    _tile('Character Picker', 'character_picker_screen.dart', _anyBook == null ? null : () => _goTo(CharacterPickerScreen(bookId: _anyBook!.id))),
                    _tile('Creator Wizard', 'creator_wizard_screen.dart', _anyBook == null ? null : () => _goTo(CreatorWizardScreen(bookId: _anyBook!.id))),
                    _tile('Record Your Story', 'record_story_screen.dart', _anyBook == null ? null : () => _goTo(RecordStoryScreen(bookId: _anyBook!.id))),
                    _section('Needs a book + character'),
                    _tile(
                      'Avatar Gallery',
                      'avatar_gallery_screen.dart',
                      (_anyBook == null || _testCharacter == null)
                          ? null
                          : () => _goTo(AvatarGalleryScreen(
                                characterId: _testCharacter!.id,
                                characterName: _testCharacter!.name,
                                currentAvatarUrl: _testCharacter!.cartoonAvatarUrl,
                                bookId: _anyBook!.id,
                              )),
                    ),
                    _tile(
                      'Choose Different Character',
                      'choose_different_character_screen.dart',
                      (_anyBook == null || _testCharacter == null)
                          ? null
                          : () => _goTo(ChooseDifferentCharacterScreen(bookId: _anyBook!.id, currentCharacterId: _testCharacter!.id)),
                    ),
                    _section('Needs a book with pages'),
                    _tile(
                      'Record Voice (per page)',
                      'record_voice_screen.dart',
                      _testPage == null
                          ? null
                          : () => _goTo(RecordVoiceScreen(
                                pageId: _testPage!.id,
                                pageNumber: _testPage!.pageNumber,
                                scriptText: _testPage!.scriptText,
                              )),
                    ),
                    _tile(
                      'Upload Photo (per page)',
                      'upload_photo_screen.dart',
                      _testPage == null
                          ? null
                          : () => _goTo(UploadPhotoScreen(pageId: _testPage!.id, pageNumber: _testPage!.pageNumber)),
                    ),
                    _section('Needs a story template'),
                    _tile(
                      'Template Page Editor',
                      'template_page_editor_screen.dart',
                      _testTemplate == null
                          ? null
                          : () => _goTo(TemplatePageEditorScreen(templateId: _testTemplate!.id, templateTitle: _testTemplate!.title)),
                    ),
                    _section('Needs a book with a generated video'),
                    _tile(
                      'Video Player',
                      'video_player_screen.dart',
                      _bookWithVideo == null
                          ? null
                          : () => _goTo(VideoPlayerScreen(videoUrl: '${ApiService.baseUrl}${_bookWithVideo!.videoUrl}')),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  Widget _tile(String label, String fileName, VoidCallback? onTap) {
    final verified = _verifiedFiles.contains(fileName);
    return ListTile(
      leading: Checkbox(
        value: verified,
        activeColor: Colors.green,
        onChanged: (checked) => _toggleVerified(fileName, checked == true),
      ),
      title: Row(
        children: [
          Text(fileName, style: TextStyle(color: onTap == null ? Colors.grey : Colors.grey.shade700)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: onTap == null ? Colors.grey : null)),
        ],
      ),
      trailing: onTap == null ? const Text('no test data', style: TextStyle(fontSize: 11, color: Colors.grey)) : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
