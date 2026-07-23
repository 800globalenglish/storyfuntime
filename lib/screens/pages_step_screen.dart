import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'record_voice_screen.dart';
import 'home_screen.dart';

class PagesStepScreen extends StatefulWidget {
  final String bookId;

  const PagesStepScreen({super.key, required this.bookId});

  @override
  State<PagesStepScreen> createState() => _PagesStepScreenState();
}

class _PagesStepScreenState extends State<PagesStepScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;
  String? _generatingScenePageId;
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

  void _finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 3 of 3: Bring It to Life')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record your voice and create pictures for each page.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<Book>(
                future: _bookFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final pages = snapshot.data!.pages;
                  return ListView.builder(
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
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
                                children: [
                                  CircleAvatar(child: Text('${page.pageNumber}')),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(page.scriptText)),
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
                                          onPressed: () => _generateScene(page.id, page.cartoonImageUrl),
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
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}
