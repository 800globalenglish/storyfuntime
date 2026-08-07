import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'creator_wizard_screen.dart'; // adjust this import path if creator_wizard_screen.dart lives elsewhere
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../widgets/voice_text_field.dart';
import '../widgets/audio_meter.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

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

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

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
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => Scaffold(
        backgroundColor: ThemeController.instance.backgroundData.color,
        bottomNavigationBar: const DebugScreenTag('record_story_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Record Your Story'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
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
            VoiceTextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
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
              child: Text(
                _isRecording ? 'Recording... tap to stop' : 'Tap to start telling your story',
                style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
              ),
            ),
            if (_isRecording) ...[
              const SizedBox(height: 12),
              AudioMeter(recorder: _audioRecorder),
            ],
            const SizedBox(height: 16),
            if (_hasRecording) ...[
              AnimatedBuilder(
                animation: ThemeController.instance.listenable,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: _buttonHeight,
                            child: ElevatedButton.icon(
                              onPressed: _togglePlayback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeController.instance.buttonColor(ButtonRole.primary),
                                foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.primary),
                                shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                              ),
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
                              label: Text(_isPlaying ? 'Pause' : 'Play Back', style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: _buttonHeight,
                            child: ElevatedButton.icon(
                              onPressed: _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeController.instance.buttonColor(ButtonRole.secondary),
                                foregroundColor: ThemeController.instance.buttonTextColor(ButtonRole.secondary),
                                shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                              ),
                              icon: const Icon(Icons.mic, size: 32),
                              label: const Text('Re-record', style: TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: _buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.green.shade800,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                        ),
                        icon: _isGenerating
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_stories, size: 32),
                        label: Text(
                          _isGenerating ? 'Generating your book...' : 'Generate Book',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}