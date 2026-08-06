import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'audio_meter.dart';

/// A TextField with a built-in mic button - tap to record, tap again to stop
/// and transcribe, and the transcript is appended to whatever text is
/// already there. Shows the shared AudioMeter while recording and a spinner
/// while transcribing. Drop this in anywhere a screen needs voice input
/// instead of reimplementing add_character_screen.dart's instructions-field
/// mic logic.
class VoiceTextField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final int? maxLines;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;
  final Color? micColor;

  const VoiceTextField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.style,
    this.autofocus = false,
    this.micColor,
  });

  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField> {
  final _apiService = ApiService();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path == null) return;

      setState(() {
        _isTranscribing = true;
        _errorMessage = null;
      });

      try {
        // On web, `path` is a blob URL - fetch its bytes first.
        final response = await http.get(Uri.parse(path));
        final audioBytes = response.bodyBytes;

        final transcript = await _apiService.transcribeAudio(audioBytes);

        setState(() {
          final existing = widget.controller.text.trim();
          widget.controller.text = existing.isEmpty ? transcript : '$existing $transcript';
        });
      } catch (e) {
        setState(() => _errorMessage = 'Could not transcribe audio: $e');
      } finally {
        setState(() => _isTranscribing = false);
      }
    } else {
      try {
        await _audioRecorder.start(const RecordConfig(), path: 'voice_text_field_audio');
        setState(() {
          _isRecording = true;
          widget.controller.clear();
        });
      } catch (e) {
        setState(() => _errorMessage = 'Could not start recording. Please allow microphone access: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final micColor = widget.micColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          textAlign: widget.textAlign,
          style: widget.style,
          autofocus: widget.autofocus,
          decoration: widget.decoration.copyWith(
            suffixIcon: _isTranscribing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop_circle : Icons.mic,
                      color: micColor,
                      size: _isRecording ? 20 : null,
                    ),
                    onPressed: _toggleRecording,
                  ),
          ),
        ),
        if (_isRecording) ...[
          const SizedBox(height: 8),
          AudioMeter(recorder: _audioRecorder),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ],
    );
  }
}
