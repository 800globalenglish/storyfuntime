import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'creator_wizard_screen.dart';
import 'book_reader_screen.dart';
import 'video_player_screen.dart';
import '../utils/fade_route.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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
  bool _isGeneratingPdf = false;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

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
      FadeRoute(page: BookReaderScreen(bookId: widget.bookId)),
    );
  }

  Future<void> _goToChangeBook() async {
    await Navigator.push(
      context,
      FadeRoute(page: CreatorWizardScreen(bookId: widget.bookId)),
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
      FadeRoute(page: VideoPlayerScreen(videoUrl: '${ApiService.baseUrl}$videoUrl')),
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

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await _apiService.generatePdf(bookId: widget.bookId);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.t('failed_to_generate_pdf')} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _viewPdf(String pdfUrl) async {
    final uri = Uri.parse('${ApiService.baseUrl}$pdfUrl');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('could_not_open_pdf'))),
        );
      }
    }
  }

  Future<void> _sharePdf(String pdfUrl) async {
    final fullUrl = '${ApiService.baseUrl}$pdfUrl';
    await Clipboard.setData(ClipboardData(text: fullUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('pdf_link_copied'))),
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
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => FutureBuilder<Book>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: ThemeController.instance.backgroundData.color,
            bottomNavigationBar: const DebugScreenTag('book_summary_screen.dart'),
            appBar: AppBar(
              actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: ThemeController.instance.backgroundData.color,
            bottomNavigationBar: const DebugScreenTag('book_summary_screen.dart'),
            appBar: AppBar(
              actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
            ),
            body: Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}')),
          );
        }
        final book = snapshot.data!;
        final hasAnyAudio = book.pages.any((p) => p.audioUrl != null);

        return Scaffold(
          backgroundColor: ThemeController.instance.backgroundData.color,
          bottomNavigationBar: const DebugScreenTag('book_summary_screen.dart'),
          appBar: AppBar(
            centerTitle: true,
            title: Text(book.title, style: const TextStyle(fontSize: 22)),
            actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
          ),
          body: SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Center(
                  child: Image.asset(
                    'assets/images/StoryFunTime_MainLogo.png',
                    height: 270,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: _goToReadBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeController.instance.buttonColor(ButtonRole.primary),
                      foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.primary),
                      shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                    ),
                    icon: const Icon(Icons.menu_book, size: 32),
                    label: Text(AppStrings.t('read_book'), style: const TextStyle(fontSize: 28)),
                  ),
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
                      child: SizedBox(
                        height: _buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 32),
                          label: Text(AppStrings.t('video_ready'), style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: hasAnyAudio ? _generateVideo : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                            foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
                            disabledBackgroundColor: Colors.grey.shade400,
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          icon: const Icon(Icons.movie_creation_outlined, size: 32),
                          label: Text(
                            hasAnyAudio ? AppStrings.t('generate_video') : AppStrings.t('no_video_yet'),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      if (!hasAnyAudio) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.t('record_narration_first'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 12),
                if (_isGeneratingPdf)
                  const Center(child: CircularProgressIndicator())
                else if (book.pdfUrl != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') {
                        _viewPdf(book.pdfUrl!);
                      } else if (value == 'share') {
                        _sharePdf(book.pdfUrl!);
                      } else if (value == 'regenerate') {
                        _generatePdf();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'view', child: Row(children: [const Icon(Icons.picture_as_pdf), const SizedBox(width: 12), Text(AppStrings.t('view_pdf'))])),
                      PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share), const SizedBox(width: 12), Text(AppStrings.t('share'))])),
                      PopupMenuItem(value: 'regenerate', child: Row(children: [const Icon(Icons.refresh), const SizedBox(width: 12), Text(AppStrings.t('regenerate_pdf'))])),
                    ],
                    child: IgnorePointer(
                      child: SizedBox(
                        height: _buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                          ),
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 32),
                          label: Text(AppStrings.t('view_pdf'), style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: _buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _generatePdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                        foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
                        shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 32),
                      label: Text(AppStrings.t('generate_pdf'), style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: _goToChangeBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeController.instance.buttonColor(ButtonRole.accent),
                      foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.accent),
                      shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 32),
                    label: Text(AppStrings.t('change_book'), style: const TextStyle(fontSize: 28)),
                  ),
                ),
                ],
            ),
          ),
          ),
        );
      },
    ),
    );
  }
}
