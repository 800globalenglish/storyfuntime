import 'package:flutter/material.dart';

/// Flip to false to hide every screen-file tag in one shot without
/// touching the ~28 screens that reference DebugScreenTag.
const bool kShowDebugScreenTags = true;

/// Dev-only label pinned to the bottom of a screen showing which file
/// it's built from - handy for matching what's on screen to the right
/// source file while several similar-looking screens are in flight.
class DebugScreenTag extends StatelessWidget {
  final String fileName;
  const DebugScreenTag(this.fileName, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!kShowDebugScreenTags) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        fileName,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
