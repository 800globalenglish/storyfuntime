import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'creator_wizard_screen.dart';
import 'book_reader_screen.dart';

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

  Future<void> _watchVideo(String videoUrl) async {
    final uri = Uri.parse('${ApiService.baseUrl}$videoUrl');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the video.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book')),
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
                  label: const Text('Read Book'),
                ),
                const SizedBox(height: 12),
                if (_isGeneratingVideo)
                  const Center(child: CircularProgressIndicator())
                else if (book.videoUrl != null)
                  ElevatedButton.icon(
                    onPressed: () => _watchVideo(book.videoUrl!),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Watch / Download Video'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _generateVideo,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: const Text('Generate Video'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _goToChangeBook,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Change Book'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
