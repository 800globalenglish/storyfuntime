import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/story_type.dart';
import 'book_detail_screen.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../widgets/voice_text_field.dart';

class CreateBookScreen extends StatefulWidget {
  final List<String>? preSelectedCharacterIds;

  const CreateBookScreen({super.key, this.preSelectedCharacterIds});

  @override
  State<CreateBookScreen> createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends State<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  final _apiService = ApiService();
  bool _isSubmitting = false;
  String? _resultMessage;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    final preSelected = widget.preSelectedCharacterIds;
    if (preSelected != null && preSelected.isNotEmpty) {
      // Characters were already chosen - skip asking for title/theme here,
      // that's handled on Book Details via "Generate Story" instead. Story
      // Type is picked there too, not at creation time.
      _isSubmitting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _createWithDefaults(preSelected));
    }
  }

  Future<void> _createWithDefaults(List<String> characterIds) async {
    try {
      final book = await _apiService.createBook(
        title: 'My Story',
        theme: 'draft',
        storyType: StoryType.bedtime.apiValue,
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
        storyType: StoryType.bedtime.apiValue,
      );

      final preSelected = widget.preSelectedCharacterIds;
      if (preSelected != null && preSelected.isNotEmpty) {
        await _apiService.copyCharactersToBook(
          bookId: book.id,
          characterIds: preSelected,
        );
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: book.id)),
        );
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
            VoiceTextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
                hintText: 'e.g. Grandma and the Farm Animals',
              ),
            ),
            const SizedBox(height: 16),
            VoiceTextField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'Theme',
                border: OutlineInputBorder(),
                hintText: 'e.g. Farm animals, Bible stories',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: _buttonHeight,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Book', style: TextStyle(fontSize: 22)),
              ),
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
