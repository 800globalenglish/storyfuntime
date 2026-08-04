import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'record_voice_screen.dart';
import 'book_reader_screen.dart';
import 'video_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_nav_menu_button.dart';

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
  bool _showTimeToRecord = false;
  Timer? _timeToRecordTimer;
  String? _regeneratingTextPageId;
  bool _isGeneratingVideo = false;
  bool _instructionsHidden = false;

  // NEW - lets someone listen to a page's already-recorded audio right from
  // this list, without opening the recorder screen.
  final _pageAudioPlayer = AudioPlayer();
  String? _playingPageId;

  final Map<String, String> _lastSceneInstructions = {};

  static const List<Color> _sceneBorderColors = [
    Color(0xFF1A8BC8), // blue
    Color(0xFFE81E27), // red
    Color(0xFF7F50B2), // purple
    Color(0xFF43A047), // green
    Color(0xFFFB8C00), // orange
    Color(0xFF00ACC1), // teal
  ];

  @override
  void initState() {
    super.initState();
    _loadBook();
    _loadInstructionsPref();
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    _timeToRecordTimer?.cancel();
    _pageAudioPlayer.dispose();
    super.dispose();
  }

  void _loadBook() {
    _bookFuture = _apiService.getBook(id: widget.bookId);
  }

  void _refresh() {
    setState(() {
      _loadBook();
    });
  }

  // NEW - toggles play/stop for a page's recorded audio. Tapping a different
  // page's Listen button while one is already playing just switches to it.
  Future<void> _togglePlayAudio(String pageId, String audioUrl) async {
    if (_playingPageId == pageId) {
      await _pageAudioPlayer.stop();
      if (mounted) setState(() => _playingPageId = null);
      return;
    }

    setState(() => _playingPageId = pageId);
    await _pageAudioPlayer.play(
      UrlSource('${ApiService.baseUrl}$audioUrl?v=${DateTime.now().millisecondsSinceEpoch}'),
    );
    _pageAudioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPageId = null);
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
          SnackBar(content: Text('${AppStrings.t('failed_to_generate_video')} $e')),
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
        SnackBar(content: Text(AppStrings.t('video_link_copied'))),
      );
    }
  }

  Future<void> _downloadVideo() async {
    final uri = Uri.parse('${ApiService.baseUrl}/books/${widget.bookId}/video/download');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('could_not_download_video'))),
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
        title: Text(AppStrings.t('edit_page_text_title')),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppStrings.t('save')),
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
            SnackBar(content: Text('${AppStrings.t('failed_to_save')} $e')),
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
        title: Text(AppStrings.t('regenerate_text_title')),
        content: TextField(
          controller: instructionsController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppStrings.t('optional_instructions'),
            hintText: AppStrings.t('regenerate_text_hint'),
            border: const OutlineInputBorder(),
          ),
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
          SnackBar(content: Text('${AppStrings.t('failed_to_regenerate_text')} $e')),
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
          SnackBar(content: Text('${AppStrings.t('failed_to_revert')} $e')),
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
            SnackBar(content: Text('${AppStrings.t('failed_on_page').replaceFirst('{page}', '${page.pageNumber}')} $e')),
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
      _showTimeToRecord = true;
    });

    _timeToRecordTimer?.cancel();
    _timeToRecordTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showTimeToRecord = false);
    });
  }

  Future<void> _generateScene(String pageId, String? currentSceneUrl) async {
    final instructionsController = TextEditingController(text: _lastSceneInstructions[pageId] ?? '');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.t('generate_scene_title')),
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
              decoration: InputDecoration(
                labelText: AppStrings.t('optional_instructions'),
                hintText: AppStrings.t('generate_scene_hint'),
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
            child: Text(AppStrings.t('generate')),
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
          SnackBar(content: Text('${AppStrings.t('scene_generation_failed')} $e')),
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
        centerTitle: true,
        title: Text(
          AppStrings.t('creator_wizard_title'),
          style: const TextStyle(fontSize: 30),
        ),
        actions: [
          if (_instructionsHidden)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: AppStrings.t('show_instructions_tooltip'),
              onPressed: _showInstructionsAgain,
            ),
          const AppNavMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Book>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}'));
          }
          final book = snapshot.data!;
          final allComplete = book.pages.isNotEmpty &&
              book.pages.every((p) => p.cartoonImageUrl != null && p.audioUrl != null);
          // A book from "Record Your Story" already has audio on every page before
          // scenes exist - the normal 3-step instructions (edit text, generate
          // scenes, record sounds) don't apply since there's nothing left to record.
          final allHaveAudioAlready = book.pages.isNotEmpty &&
              book.pages.every((p) => p.audioUrl != null);
          final showInstructions = !allComplete && !_instructionsHidden && !allHaveAudioAlready;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allComplete) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 96,
                          child: ElevatedButton.icon(
                            onPressed: _goToReadBook,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A8BC8),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.menu_book, size: 32),
                            label: Text(AppStrings.t('read_book'), style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 96,
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
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share), const SizedBox(width: 12), Text(AppStrings.t('share'))])),
                              PopupMenuItem(value: 'watch', child: Row(children: [const Icon(Icons.play_circle_outline), const SizedBox(width: 12), Text(AppStrings.t('watch'))])),
                              PopupMenuItem(value: 'download', child: Row(children: [const Icon(Icons.download), const SizedBox(width: 12), Text(AppStrings.t('download'))])),
                              PopupMenuItem(value: 'regenerate', child: Row(children: [const Icon(Icons.refresh), const SizedBox(width: 12), Text(AppStrings.t('regenerate_video'))])),
                            ],
                            child: IgnorePointer(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 32),
                                label: Text(AppStrings.t('video_ready'), style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          )
                              : ElevatedButton.icon(
                            onPressed: _generateVideo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE81E27),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.movie_creation_outlined, size: 32),
                            label: Text(AppStrings.t('generate_video'), style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (showInstructions) ...[
                  _buildInstructionStep(1, AppStrings.t('edit_regenerate_text_step'), trailingIcon: Icons.more_vert),
                  const SizedBox(height: 8),
                ],
                if (!allComplete)
                  Row(
                    children: [
                      if (showInstructions) ...[
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.purple,
                          child: Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 96,
                          child: ElevatedButton.icon(
                            onPressed: _generatingScenePageId != null
                                ? null
                                : () => _generateAllScenes(book.pages),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7F50B2),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.auto_fix_high, size: 32),
                            label: Text(
                              _generatingScenePageId != null
                                  ? AppStrings.t('generating_scenes')
                                  : AppStrings.t('generate_all_screens'),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (showInstructions) ...[
                  const SizedBox(height: 8),
                  _buildInstructionStep(3, AppStrings.t('record_sounds_step')),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _hideInstructions,
                      child: Text(AppStrings.t('hide_instructions')),
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
                    child: Text(
                      AppStrings.t('magic_happens'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (_showTimeToRecord)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEDC8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7CB342)),
                    ),
                    child: Text(
                      AppStrings.t('time_to_record'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                Expanded(
                  child: book.pages.isEmpty
                      ? Text(AppStrings.t('no_pages_yet'))
                      : ListView.builder(
                    itemCount: book.pages.length,
                    itemBuilder: (context, index) {
                      final page = book.pages[index];
                      final hasAudio = page.audioUrl != null;
                      final hasScene = page.cartoonImageUrl != null;
                      final isGeneratingThisScene = _generatingScenePageId == page.id;
                      final isPlayingThisPage = _playingPageId == page.id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _sceneBorderColors[index % _sceneBorderColors.length],
                            width: 5,
                          ),
                        ),
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
                                      PopupMenuItem(value: 'edit', child: Text(AppStrings.t('edit_text'))),
                                      PopupMenuItem(value: 'regenerate', child: Text(AppStrings.t('regenerate_text_menu'))),
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
                                    label: Text(hasScene ? AppStrings.t('regenerate_scene') : AppStrings.t('generate_scene')),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _goToRecordVoice(page.id, page.pageNumber, page.scriptText),
                                    icon: Icon(
                                      hasAudio ? Icons.check_circle : Icons.mic_none,
                                      color: hasAudio ? Colors.green : null,
                                    ),
                                    label: Text(hasAudio ? AppStrings.t('voice_recorded') : AppStrings.t('record_voice')),
                                  ),
                                  // NEW - Listen button, only shown once a page has audio.
                                  if (hasAudio)
                                    IconButton(
                                      icon: Icon(
                                        isPlayingThisPage ? Icons.stop_circle : Icons.play_circle_outline,
                                      ),
                                      tooltip: isPlayingThisPage ? 'Stop' : 'Listen',
                                      onPressed: () => _togglePlayAudio(page.id, page.audioUrl!),
                                    ),
                                  if (hasScene)
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined),
                                      tooltip: AppStrings.t('view_scene_tooltip'),
                                      onPressed: () => _viewScene(page.cartoonImageUrl!),
                                    ),
                                  if (page.previousCartoonImageUrl != null)
                                    IconButton(
                                      icon: const Icon(Icons.undo),
                                      tooltip: AppStrings.t('revert_scene_tooltip'),
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