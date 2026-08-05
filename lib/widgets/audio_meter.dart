import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

class AudioMeter extends StatefulWidget {
  final AudioRecorder recorder;
  const AudioMeter({super.key, required this.recorder});

  @override
  State<AudioMeter> createState() => _AudioMeterState();
}

class _AudioMeterState extends State<AudioMeter> {
  double _level = 0.0;
  StreamSubscription<Amplitude>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amp) {
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() => _level = normalized);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final barLevel = (_level * 5 - i).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 8 + barLevel * 24,
          decoration: BoxDecoration(
            color: const Color(0xFF784AAA),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
