import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'characters_step_screen.dart';

class CreateBookScreen extends StatefulWidget {
  const CreateBookScreen({super.key});

  @override
  State<CreateBookScreen> createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends State<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  final _apiService = ApiService();

  bool _isSubmitting = false;
  String? _resultMessage;

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
        userId: 'test-user-1',
        title: _titleController.text.trim(),
        theme: _themeController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CharactersStepScreen(bookId: book.id)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Story Book')),
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
