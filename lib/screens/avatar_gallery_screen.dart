import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'book_reader_screen.dart';

class AvatarGalleryScreen extends StatefulWidget {
  final String characterId;
  final String characterName;
  final String userId;
  final String? currentAvatarUrl;
  final String bookId;

  const AvatarGalleryScreen({
    super.key,
    required this.characterId,
    required this.characterName,
    required this.userId,
    required this.bookId,
    this.currentAvatarUrl,
  });

  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _historyFuture;
  late Future<Map<String, int>> _statsFuture;
  String? _busyUrl;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _statsFuture = _apiService.getUserStats(userId: widget.userId);
  }

  void _loadHistory() {
    _historyFuture = _apiService.getAvatarHistory(characterId: widget.characterId);
  }

  Future<void> _selectAvatar(String url) async {
    setState(() {
      _busyUrl = url;
    });
    try {
      await _apiService.selectAvatar(characterId: widget.characterId, url: url);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select character: $e')),
        );
        setState(() {
          _busyUrl = null;
        });
      }
    }
  }

  Future<void> _deleteAvatar(String historyId, String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this character?'),
        content: const Text('This cannot be undone.'),
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

    if (confirm != true) return;

    setState(() {
      _busyUrl = url;
    });

    try {
      await _apiService.deleteAvatarHistoryEntry(
        characterId: widget.characterId,
        historyId: historyId,
      );
      setState(() {
        _busyUrl = null;
        _loadHistory();
        _statsFuture = _apiService.getUserStats(userId: widget.userId);
      });
    } catch (e) {
      final message = e.toString().contains('currently selected')
          ? 'This image is being used and can\'t be deleted. Choose a different one first.'
          : 'Failed to delete: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      setState(() {
        _busyUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.characterName}\'s characters')),
      body: Column(
        children: [
          FutureBuilder<Map<String, int>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final created = snapshot.data!['totalCharactersCreated'];
              final deleted = snapshot.data!['totalCharactersDeleted'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Total characters created: $created   \u2022   Total characters deleted: $deleted',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(child: Text('No past characters yet.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final url = item['url'] as String;
                    final historyId = item['id'] as String;
                    final isBusy = _busyUrl == url;
                    final isCurrent = widget.currentAvatarUrl != null && widget.currentAvatarUrl == url;

                    return GestureDetector(
                      onTap: isBusy ? null : () => _selectAvatar(url),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'http://localhost:5220$url',
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (isCurrent)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green, width: 3),
                                ),
                              ),
                            ),
                          if (isCurrent)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookReaderScreen(bookId: widget.bookId),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'In use',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.menu_book, color: Colors.white, size: 13),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (!isCurrent)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                  onPressed: isBusy ? null : () => _deleteAvatar(historyId, url),
                                ),
                              ),
                            ),
                          if (isBusy)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
