import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/story_type.dart';
import 'characters_step_screen.dart';
import 'book_detail_screen.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class CreateBookScreen extends StatefulWidget {
  final List<String>? preSelectedCharacterIds;

  const CreateBookScreen({super.key, this.preSelectedCharacterIds});

  @override
  State<CreateBookScreen> createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends State<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  StoryType _selectedStoryType = StoryType.bedtime;
  final _apiService = ApiService();
  bool _isSubmitting = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    final preSelected = widget.preSelectedCharacterIds;
    if (preSelected != null && preSelected.isNotEmpty) {
      // Characters were already chosen - skip the full title/theme form,
      // that's handled on Book Details via "Generate Story" instead. Still
      // let them pick a story type though, via a lightweight dialog rather
      // than routing through the full form.
      _isSubmitting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptStoryTypeThenCreate(preSelected));
    }
  }

  Future<void> _promptStoryTypeThenCreate(List<String> characterIds) async {
    var selectedType = StoryType.bedtime;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose a Story Type'),
          content: DropdownButtonFormField<StoryType>(
            value: selectedType,
            style: const TextStyle(fontSize: 22, color: Colors.black),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final type in StoryType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.label, style: const TextStyle(fontSize: 22)),
                ),
            ],
            onChanged: (value) => setDialogState(() => selectedType = value ?? StoryType.bedtime),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      if (mounted) Navigator.pop(context);
      return;
    }

    await _createWithDefaults(characterIds, selectedType);
  }

  Future<void> _createWithDefaults(List<String> characterIds, StoryType storyType) async {
    try {
      final book = await _apiService.createBook(
        title: 'My Story',
        theme: 'draft',
        storyType: storyType.apiValue,
      );
      await _apiService.copyCharactersToBook(
        bookId: book.id,
        characterIds: characterIds,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: book.id)),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _resultMessage = 'Error: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _themeController.text.trim().isEmpty) {
      setState(() {
        _resultMessage = 'Please fill in both fields.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
    });

    try {
      final book = await _apiService.createBook(
        title: _titleController.text.trim(),
        theme: _themeController.text.trim(),
        storyType: _selectedStoryType.apiValue,
      );

      final preSelected = widget.preSelectedCharacterIds;
      if (preSelected != null && preSelected.isNotEmpty) {
        await _apiService.copyCharactersToBook(
          bookId: book.id,
          characterIds: preSelected,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: book.id)),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CharactersStepScreen(bookId: book.id)),
          );
        }
      }
      return;
    } catch (e) {
      setState(() {
        _resultMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preSelected = widget.preSelectedCharacterIds;
    if (preSelected != null && preSelected.isNotEmpty) {
      // Auto-creating in the background - just show a spinner.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('create_book_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Create a Story Book'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
                hintText: 'e.g. Grandma and the Farm Animals',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'Theme',
                border: OutlineInputBorder(),
                hintText: 'e.g. Farm animals, Bible stories',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StoryType>(
              value: _selectedStoryType,
              style: const TextStyle(fontSize: 22, color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Story Type',
                labelStyle: TextStyle(fontSize: 22),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final type in StoryType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.label, style: const TextStyle(fontSize: 22)),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedStoryType = value ?? StoryType.bedtime),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Create Book'),
            ),
            const SizedBox(height: 24),
            if (_resultMessage != null)
              Text(
                _resultMessage!,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
