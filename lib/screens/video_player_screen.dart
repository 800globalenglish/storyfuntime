import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

/// Plays a video right inside the app - no new browser tab, no leaving
/// the screen the person was already on.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isReady = true);
      _controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not load the video: $e');
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('video_player_screen.dart'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Your Story Video'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
              )
            : !_isReady
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.deepPurple,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            icon: Icon(
                              _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: () {
                              setState(() {
                                _controller.value.isPlaying ? _controller.pause() : _controller.play();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
