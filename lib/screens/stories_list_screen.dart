import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import 'create_book_screen.dart';
import 'book_detail_screen.dart';
import 'book_summary_screen.dart';

class StoriesListScreen extends StatefulWidget {
  const StoriesListScreen({super.key});

  @override
  State<StoriesListScreen> createState() => _StoriesListScreenState();
}

class _StoriesListScreenState extends State<StoriesListScreen> {
  final _apiService = ApiService();
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _loadBooks();
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

  void _loadBooks() {
    _booksFuture = _apiService.getBooks();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadBooks();
    });
  }

  Future<void> _goToCreateBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateBookScreen()),
    );
    _refresh();
  }

  Future<void> _confirmDelete(String bookId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.t('delete_this_book_title')),
        content: Text(AppStrings.t('delete_book_confirm').replaceFirst('{title}', title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteBook(bookId: bookId);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.t('failed_to_delete')} $e')),
          );
        }
      }
    }
  }

  Future<void> _goToBookDetail(String bookId) async {
    final book = await _apiService.getBook(id: bookId);
    if (!mounted) return;

    if (book.pages.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: bookId)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BookSummaryScreen(bookId: bookId)),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('my_story_books'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Book>>(
          future: _booksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}'));
            }
            final books = snapshot.data ?? [];
            if (books.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 100,
                          child: ElevatedButton(
                            onPressed: _goToCreateBook,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              AppStrings.t('create_your_first_story'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final thumbnailUrl = book.characters.isNotEmpty && book.characters.first.cartoonAvatarUrl != null
                    ? book.characters.first.cartoonAvatarUrl
                    : null;
                return ListTile(
                  title: Text(book.title),
                  subtitle: Text('${book.theme} - ${book.status}'),
                  leading: thumbnailUrl != null
                      ? CircleAvatar(
                    backgroundImage: NetworkImage('${ApiService.baseUrl}$thumbnailUrl'),
                  )
                      : const CircleAvatar(child: Icon(Icons.menu_book)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(book.id, book.title),
                  ),
                  onTap: () => _goToBookDetail(book.id),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          final books = snapshot.data ?? [];
          if (books.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: _goToCreateBook,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
