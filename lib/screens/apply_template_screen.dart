import 'package:flutter/material.dart';
import '../models/story_template.dart';
import '../models/character.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'book_detail_screen.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class ApplyTemplateScreen extends StatefulWidget {
  final String bookId;

  const ApplyTemplateScreen({super.key, required this.bookId});

  @override
  State<ApplyTemplateScreen> createState() => _ApplyTemplateScreenState();
}

class _ApplyTemplateScreenState extends State<ApplyTemplateScreen> {
  final _apiService = ApiService();
  late Future<List<StoryTemplate>> _templatesFuture;
  late Future<List<Character>> _charactersFuture;

  StoryTemplate? _selectedTemplate;
  final Map<String, String> _roleToCharacterId = {};
  bool _isSubmitting = false;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    _templatesFuture = _apiService.getStoryTemplates();
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

  void _selectTemplate(StoryTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _roleToCharacterId.clear();
    });
  }

  Future<void> _apply() async {
    final template = _selectedTemplate;
    if (template == null) return;

    final roles = template.detectedRoles;
    if (roles.any((role) => _roleToCharacterId[role] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('please_choose_character_for_role'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.applyTemplate(
        bookId: widget.bookId,
        templateId: template.id,
        roleToCharacterId: _roleToCharacterId,
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
          SnackBar(content: Text('${AppStrings.t('failed_to_apply_template')} $e')),
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
      bottomNavigationBar: const DebugScreenTag('apply_template_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: Text(AppStrings.t('story_templates')),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: FutureBuilder<List<StoryTemplate>>(
        future: _templatesFuture,
        builder: (context, templateSnapshot) {
          if (templateSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (templateSnapshot.hasError) {
            return Center(child: Text('${AppStrings.t('error_prefix')} ${templateSnapshot.error}'));
          }
          final templates = templateSnapshot.data ?? [];
          if (templates.isEmpty) {
            return Center(child: Text(AppStrings.t('no_story_templates_yet')));
          }

          if (_selectedTemplate == null) {
            return ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return ListTile(
                  title: Text(template.title),
                  subtitle: Text('${template.theme} - ${template.pages.length} ${AppStrings.t('pages_suffix')}'),
                  leading: const Icon(Icons.auto_stories),
                  onTap: () => _selectTemplate(template),
                );
              },
            );
          }

          final roles = _selectedTemplate!.detectedRoles.toList()..sort();

          return FutureBuilder<List<Character>>(
            future: _charactersFuture,
            builder: (context, characterSnapshot) {
              if (characterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (characterSnapshot.hasError) {
                return Center(child: Text('${AppStrings.t('error_prefix')} ${characterSnapshot.error}'));
              }
              final characters = characterSnapshot.data ?? [];

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_selectedTemplate!.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => setState(() => _selectedTemplate = null),
                      child: Text(AppStrings.t('choose_different_template')),
                    ),
                    const SizedBox(height: 16),
                    Text(AppStrings.t('who_plays_each_role')),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: roles.map((role) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              initialValue: _roleToCharacterId[role],
                              decoration: InputDecoration(
                                labelText: role,
                                border: const OutlineInputBorder(),
                              ),
                              items: characters.map((c) {
                                return DropdownMenuItem(value: c.id, child: Text(c.name));
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (value != null) {
                                    _roleToCharacterId[role] = value;
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(
                      height: _buttonHeight,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(AppStrings.t('apply_template'), style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
