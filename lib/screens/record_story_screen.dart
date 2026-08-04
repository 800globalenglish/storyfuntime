import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'creator_wizard_screen.dart'; // adjust this import path if creator_wizard_screen.dart lives elsewhere

class RecordStoryScreen extends StatefulWidget {
  final String bookId;

  const RecordStoryScreen({
    super.key,
    required this.bookId,
  });

  @override
  State<RecordStoryScreen> createState() => _RecordStoryScreenState();
}

class _RecordStoryScreenState extends State<RecordStoryScreen> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _apiService = ApiService();
  final _titleController = TextEditingController();
  final _themeController = TextEditingController();

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isGenerating = false;
  bool _isPlaying = false;
  String? _errorMessage;
  String? _recordingPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _titleController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: 'story_recording.webm');
        setState(() {
          _isRecording = true;
          _hasRecording = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Microphone permission was denied. Please allow microphone access and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _hasRecording = path != null;
        _recordingPath = path;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not stop recording: $e';
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    setState(() {
      _isPlaying = true;
    });
    await _audioPlayer.play(UrlSource(_recordingPath!));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _generateBook() async {
    if (_recordingPath == null) return;
    if (_titleController.text.trim().isEmpty || _themeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in a title and theme first.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // Same pattern as _generateStory on Book Details - save title/theme first,
      // then generate the pages.
      await _apiService.updateBook(
        bookId: widget.bookId,
        title: _titleController.text.trim(),
        theme: _themeController.text.trim(),
      );

      final response = await http.get(Uri.parse(_recordingPath!));
      await _apiService.generateFromRecording(
        bookId: widget.bookId,
        audioBytes: response.bodyBytes,
      );

      // Same forward-navigation pattern as _generateStory in book_detail_screen -
      // successfully generating pages moves straight into the Creator Wizard.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreatorWizardScreen(bookId: widget.bookId)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate your book: $e';
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Your Story')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _themeController,
              decoration: const InputDecoration(
                labelText: 'Theme',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            Center(
              child: Material(
                color: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(_isRecording ? 'Recording... tap to stop' : 'Tap to start telling your story'),
            ),
            const SizedBox(height: 16),
            if (_hasRecording) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _togglePlayback,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Pause' : 'Play Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Re-record'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateBook,
                icon: _isGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_stories),
                label: Text(_isGenerating ? 'Generating your book...' : 'Generate Book'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}