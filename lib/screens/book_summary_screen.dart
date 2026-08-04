import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'creator_wizard_screen.dart';
import 'book_reader_screen.dart';
import 'video_player_screen.dart';
import '../widgets/app_nav_menu_button.dart';

class BookSummaryScreen extends StatefulWidget {
  final String bookId;

  const BookSummaryScreen({super.key, required this.bookId});

  @override
  State<BookSummaryScreen> createState() => _BookSummaryScreenState();
}

class _BookSummaryScreenState extends State<BookSummaryScreen> {
  final _apiService = ApiService();
  late Future<Book> _bookFuture;
  bool _isGeneratingVideo = false;

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

  void _goToReadBook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookReaderScreen(bookId: widget.bookId)),
    );
  }

  Future<void> _goToChangeBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreatorWizardScreen(bookId: widget.bookId)),
    );
    _refresh();
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

  void _watchVideo(String videoUrl) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('book_title_appbar')),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
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

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _goToReadBook,
                  icon: const Icon(Icons.menu_book),
                  label: Text(AppStrings.t('read_book')),
                ),
                const SizedBox(height: 12),
                if (_isGeneratingVideo)
                  const Center(child: CircularProgressIndicator())
                else if (book.videoUrl != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'share') {
                        _shareVideo(book.videoUrl!);
                      } else if (value == 'watch') {
                        _watchVideo(book.videoUrl!);
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
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: Text(AppStrings.t('video_ready')),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _generateVideo,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: Text(AppStrings.t('generate_video')),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _goToChangeBook,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(AppStrings.t('change_book')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
