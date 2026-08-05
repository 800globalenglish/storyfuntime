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
      // Ambient/idle mic levels (especially with auto-gain-control laptop
      // mics) commonly sit around -35 to -45 dB, not near silence - a
      // -60..0 range left the first couple bars pinned lit at rest. The
      // narrower, higher floor helps, but bar 0 only needs 20% to fully
      // light, so squaring the result compresses the low end further -
      // quiet/ambient levels stay near the bottom, only real speech climbs.
      final raw = ((amp.current + 45) / 35).clamp(0.0, 1.0);
      final normalized = raw * raw;
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
    // Fixed height matching the tallest possible bar (8 + 1*24) so the
    // meter's own layout size never changes as bars animate - otherwise
    // whatever's below it (e.g. a button) jumps up and down while it plays.
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
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
      ),
    );
  }
}
