import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pages_step_screen.dart';

class GenerateStoryScreen extends StatefulWidget {
  final String bookId;
  final bool isWizard;

  const GenerateStoryScreen({super.key, required this.bookId, this.isWizard = false});

  @override
  State<GenerateStoryScreen> createState() => _GenerateStoryScreenState();
}

class _GenerateStoryScreenState extends State<GenerateStoryScreen> {
  final _apiService = ApiService();

  bool _isGenerating = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<TextEditingController> _pageControllers = [];

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final pages = await _apiService.generateScript(bookId: widget.bookId, pageCount: 3);
      setState(() {
        _pageControllers = pages.map((p) => TextEditingController(text: p)).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveAllPages() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _apiService.deleteAllPages(bookId: widget.bookId);
      for (int i = 0; i < _pageControllers.length; i++) {
        await _apiService.addPage(
          bookId: widget.bookId,
          pageNumber: i + 1,
          scriptText: _pageControllers[i].text.trim(),
        );
      }
      if (mounted) {
        if (widget.isWizard) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PagesStepScreen(bookId: widget.bookId)),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving pages: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _pageControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Story')),
      body: _isGenerating
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _pageControllers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generate,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Text(
                      'Grok wrote this story for you. Edit anything you like before saving.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    for (int i = 0; i < _pageControllers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextField(
                          controller: _pageControllers[i],
                          maxLines: null,
                          decoration: InputDecoration(
                            labelText: 'Page ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAllPages,
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('Save These Pages'),
                    ),
                  ],
                ),
    );
  }
}
