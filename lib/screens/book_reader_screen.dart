import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/book.dart';
import '../services/api_service.dart';

class BookReaderScreen extends StatefulWidget {
  final String bookId;

  const BookReaderScreen({super.key, required this.bookId});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final _apiService = ApiService();
  final _audioPlayer = AudioPlayer();
  final _pageController = PageController();

  late Future<Book> _bookFuture;
  int _currentPage = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _bookFuture = _apiService.getBook(id: widget.bookId);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String? audioUrl) async {
    if (audioUrl == null) return;
    setState(() {
      _isPlaying = true;
    });
    await _audioPlayer.play(UrlSource('http://localhost:5220$audioUrl'));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Book>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final book = snapshot.data!;
          final pages = book.pages;

          if (pages.isEmpty) {
            return const Center(
              child: Text(
                'This book has no pages yet.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    _stopAudio();
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                      child: Column(
                        children: [
                          Expanded(
                            child: page.cartoonImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                'http://localhost:5220${page.cartoonImageUrl}?v=${DateTime.now().millisecondsSinceEpoch}',
                                fit: BoxFit.contain,
                              ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported, color: Colors.white38, size: 48),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.scriptText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          const SizedBox(height: 16),
                          if (page.audioUrl != null)
                            IconButton(
                              iconSize: 48,
                              color: Colors.white,
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              onPressed: () {
                                if (_isPlaying) {
                                  _stopAudio();
                                } else {
                                  _playAudio(page.audioUrl);
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Page ${_currentPage + 1} of ${pages.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: _currentPage > 0
                          ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: _currentPage < pages.length - 1
                          ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                          : null,
                    ),
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
