import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

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
  bool _isUploading = false;
  bool _isPlaying = false;
  String? _errorMessage;
  String? _recordingPath;

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

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    setState(() {
      _isPlaying = true;
    });
    await _audioPlayer.play(UrlSource(_recordingPath!));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _saveRecording() async {
    if (_recordingPath == null) return;
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(_recordingPath!));
      await _apiService.uploadAudio(pageId: widget.pageId, audioBytes: response.bodyBytes);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save recording: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record Page ${widget.pageNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.scriptText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            Center(
              child: GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(_isRecording ? 'Recording... tap to stop' : 'Tap to record'),
            ),
            if (_hasRecording) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isPlaying ? null : _playRecording,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play back'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveRecording,
                icon: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isUploading ? 'Saving...' : 'Save Recording'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
