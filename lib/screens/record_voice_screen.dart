import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../widgets/audio_meter.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/scene_border_colors.dart';

class RecordVoiceScreen extends StatefulWidget {
  final String pageId;
  final int pageNumber;
  final String scriptText;


  const RecordVoiceScreen({
    super.key,
    required this.pageId,
    required this.pageNumber,
    required this.scriptText,
  });

  @override
  State<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

class _RecordVoiceScreenState extends State<RecordVoiceScreen> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _apiService = ApiService();

  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isPlaying = false;
  String? _errorMessage;
  String? _recordingPath;

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: 'recording.webm');
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

  void _saveRecording() {
    if (_recordingPath == null) return;
    final path = _recordingPath!;
    final pageId = widget.pageId;

    // Upload happens in the background so the person can move on right
    // away instead of waiting on the network - there's no screen left to
    // show an upload failure on, so just log it.
    () async {
      try {
        final response = await http.get(Uri.parse(path));
        await _apiService.uploadAudio(pageId: pageId, audioBytes: response.bodyBytes);
      } catch (e) {
        debugPrint('Failed to save recording in background: $e');
      }
    }();

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeKey>(
      valueListenable: ThemeController.instance.current,
      builder: (context, themeKey, _) {
        final sceneColors = sceneBorderColors(kAppThemes[themeKey]!);
        final borderColor = sceneColors[(widget.pageNumber - 1) % sceneColors.length];
        return _buildScaffold(context, borderColor);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Color borderColor) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('record_voice_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: Text('Record Page ${widget.pageNumber}'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 2.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.scriptText,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, height: 1.3),
                ),
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
              child: Text(_isRecording ? 'Recording... tap to stop' : 'Tap to record'),
            ),
            if (_isRecording) ...[
              const SizedBox(height: 12),
              AudioMeter(recorder: _audioRecorder),
            ],
            if (_hasRecording) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _togglePlayback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
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
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
                  onPressed: _saveRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                  ),
                  icon: const Icon(Icons.check, size: 32),
                  label: const Text('Save Recording', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
