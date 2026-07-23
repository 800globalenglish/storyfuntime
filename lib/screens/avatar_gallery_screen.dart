import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AvatarGalleryScreen extends StatefulWidget {
  final String characterId;
  final String characterName;

  const AvatarGalleryScreen({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _historyFuture;
  String? _selectingUrl;

  @override
  void initState() {
    super.initState();
    _historyFuture = _apiService.getAvatarHistory(characterId: widget.characterId);
  }

  Future<void> _selectAvatar(String url) async {
    setState(() {
      _selectingUrl = url;
    });
    try {
      await _apiService.selectAvatar(characterId: widget.characterId, url: url);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select avatar: $e')),
        );
        setState(() {
          _selectingUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.characterName}\'s avatars')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return const Center(child: Text('No past avatars yet.'));
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
              final isSelecting = _selectingUrl == url;

              return GestureDetector(
                onTap: isSelecting ? null : () => _selectAvatar(url),
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
                    if (isSelecting)
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
    );
  }
}
