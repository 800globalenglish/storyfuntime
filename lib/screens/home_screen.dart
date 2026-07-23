import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'create_book_screen.dart';
import 'book_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    _booksFuture = _apiService.getBooks(userId: 'test-user-1');
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
        title: const Text('Delete this book?'),
        content: Text('"$title" and all its pages, characters, and recordings will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _goToBookDetail(String bookId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookDetailScreen(bookId: bookId)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Story Books')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Book>>(
          future: _booksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final books = snapshot.data ?? [];
            if (books.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Text('No books yet. Tap + to create one!'),
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return ListTile(
                  title: Text(book.title),
                  subtitle: Text('${book.theme} - ${book.status}'),
                  leading: const Icon(Icons.menu_book),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreateBook,
        child: const Icon(Icons.add),
      ),
    );
  }
}
