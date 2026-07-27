import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'record_voice_screen.dart';
import 'book_reader_screen.dart';
import 'video_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CreatorWizardScreen extends StatefulWidget {
  final String bookId;

  const CreatorWizardScreen({super.key, required this.bookId});

  @override
  State<CreatorWizardScreen> createState() => _CreatorWizardScreenState();
}

class _CreatorWizardScreenState extends State<CreatorWizardScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;
  String? _generatingScenePageId;
  bool _isBulkGenerating = false;
  String? _regeneratingTextPageId;
  bool _isGeneratingVideo = false;
  bool _instructionsHidden = false;

  final Map<String, String> _lastSceneInstructions = {};

  @override
  void initState() {
    super.initState();
    _loadBook();
    _loadInstructionsPref();
  }

  void _loadBook() {
    _bookFuture = _apiService.getBook(id: widget.bookId);
  }

  void _refresh() {
    setState(() {
      _loadBook();
    });
  }

  Widget _buildInstructionStep(int number, String text, {IconData? trailingIcon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.purple,
            child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(text),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon, size: 18),
          ],
        ],
      ),
    );
  }

  void _goToReadBook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookReaderScreen(bookId: widget.bookId)),
    );
  }
  Future<void> _loadInstructionsPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _instructionsHidden = prefs.getBool('creator_wizard_instructions_hidden') ?? false;
    });
  }

  Future<void> _hideInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('creator_wizard_instructions_hidden', true);
    setState(() {
      _instructionsHidden = true;
    });
  }
  Future<void> _generateVideo() async {
    setState(() {
      _isGeneratingVideo = true;
    });
    try {
      await _apiService.generateVideo(bookId: widget.bookId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingVideo = false;
        });
      }
    }
  }

  void _openVideo(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoUrl: '${ApiService.baseUrl}$videoUrl')),
    );
  }

  Future<void> _shareVideo(String videoUrl) async {
    final fullUrl = '${ApiService.baseUrl}$videoUrl';
    await Clipboard.setData(ClipboardData(text: fullUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video link copied — paste it anywhere to share!')),
      );
    }
  }

  Future<void> _downloadVideo() async {
    final uri = Uri.parse('${ApiService.baseUrl}/books/${widget.bookId}/video/download');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download video')),
        );
      }
    }
  }

  Future<void> _showInstructionsAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('creator_wizard_instructions_hidden', false);
    setState(() {
      _instructionsHidden = false;
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
    if (saved != true) return;

    _refresh();

    // Chain straight into the next page that still needs a voice recording,
    // instead of dropping back to the main screen after every single save.
    if (!mounted) return;
    final freshBook = await _apiService.getBook(id: widget.bookId);
    final remaining = freshBook.pages
        .where((p) => p.pageNumber > pageNumber && p.audioUrl == null)
        .toList();
    if (remaining.isNotEmpty && mounted) {
      final next = remaining.first;
      await _goToRecordVoice(next.id, next.pageNumber, next.scriptText);
    }
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
    final instructionsController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Text'),
        content: TextField(
          controller: instructionsController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Optional instructions',
            hintText: 'e.g. make it shorter, add more excitement',
            border: OutlineInputBorder(),
          ),
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
    if (proceed != true) return;

    setState(() {
      _regeneratingTextPageId = pageId;
    });
    try {
      await _apiService.regeneratePageText(
        pageId: pageId,
        extraInstructions: instructionsController.text.trim().isEmpty
            ? null
            : instructionsController.text.trim(),
      );
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

  void _viewScene(String cartoonImageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Image.network(
              '${ApiService.baseUrl}$cartoonImageUrl?v=${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> _generateAllScenes(List<dynamic> pages) async {
    final pagesNeedingScenes = pages.where((p) => p.cartoonImageUrl == null).toList();
    if (pagesNeedingScenes.isEmpty) return;

    // Books with a lot of pages generate a lot of back-to-back AI requests,
    // which can trip rate limits - a small breather between pages keeps
    // large batches reliable without slowing down typical small books.
    final isLargeBatch = pagesNeedingScenes.length > 9;

    setState(() => _isBulkGenerating = true);

    for (final page in pagesNeedingScenes) {
      setState(() {
        _generatingScenePageId = page.id;
      });
      try {
        await _apiService.generateScene(pageId: page.id, extraInstructions: null);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed on page ${page.pageNumber}: $e')),
          );
        }
      }
      if (isLargeBatch && page != pagesNeedingScenes.last) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    setState(() {
      _generatingScenePageId = null;
      _isBulkGenerating = false;
    });
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
                    '${ApiService.baseUrl}$currentSceneUrl?v=${DateTime.now().millisecondsSinceEpoch}',
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
      appBar: AppBar(
        title: const Text('Creator Wizard'),
        actions: [
          if (_instructionsHidden)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Show instructions',
              onPressed: _showInstructionsAgain,
            ),
        ],
      ),
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
          final allComplete = book.pages.isNotEmpty &&
              book.pages.every((p) => p.cartoonImageUrl != null && p.audioUrl != null);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allComplete) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _goToReadBook,
                          icon: const Icon(Icons.menu_book),
                          label: const Text('Read Book'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isGeneratingVideo
                            ? const Center(child: CircularProgressIndicator())
                            : book.videoUrl != null
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'share') {
                                        _shareVideo(book.videoUrl!);
                                      } else if (value == 'watch') {
                                        _openVideo(book.videoUrl!);
                                      } else if (value == 'download') {
                                        _downloadVideo();
                                      } else if (value == 'regenerate') {
                                        _generateVideo();
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share), SizedBox(width: 12), Text('Share')])),
                                      PopupMenuItem(value: 'watch', child: Row(children: [Icon(Icons.play_circle_outline), SizedBox(width: 12), Text('Watch')])),
                                      PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download), SizedBox(width: 12), Text('Download')])),
                                      PopupMenuItem(value: 'regenerate', child: Row(children: [Icon(Icons.refresh), SizedBox(width: 12), Text('Regenerate Video')])),
                                    ],
                                    child: IgnorePointer(
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        label: const Text('Video Ready'),
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _generateVideo,
                                    icon: const Icon(Icons.movie_creation_outlined),
                                    label: const Text('Generate Video'),
                                  ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (!allComplete && !_instructionsHidden) ...[
                  _buildInstructionStep(1, 'Edit or Regenerate Text', trailingIcon: Icons.more_vert),
                  const SizedBox(height: 8),
                ],
                if (!allComplete)
                  Row(
                    children: [
                      if (!_instructionsHidden) ...[
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.purple,
                          child: Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatingScenePageId != null
                              ? null
                              : () => _generateAllScenes(book.pages),
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(_generatingScenePageId != null
                              ? 'Generating scenes...'
                              : 'Generate All Screens'),
                        ),
                      ),
                    ],
                  ),
                if (!allComplete && !_instructionsHidden) ...[
                  const SizedBox(height: 8),
                  _buildInstructionStep(3, 'Record Sounds'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _hideInstructions,
                      child: const Text('Hide instructions'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_isBulkGenerating)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBC02D)),
                    ),
                    child: const Text(
                      'Please wait while the magic happens :-)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
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
                                                label: Text(hasScene ? 'Regenerate Scene' : 'Generate scene'),
                                              ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => _goToRecordVoice(page.id, page.pageNumber, page.scriptText),
                                          icon: Icon(
                                            hasAudio ? Icons.check_circle : Icons.mic_none,
                                            color: hasAudio ? Colors.green : null,
                                          ),
                                          label: Text(hasAudio ? 'Voice recorded' : 'Record voice'),
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
