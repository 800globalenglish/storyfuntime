import 'package:flutter/material.dart';
import 'app_theme.dart';

/// The 6-color palette used for alternating borders around story-page
/// cards and text areas (Creator Wizard, Pages Step, Generate Story,
/// Record Voice). The first three follow the active theme
/// (primary/secondary/accent); the rest are fixed accents with no
/// theme slot of their own.
List<Color> sceneBorderColors(AppThemeData themeData) => [
  themeData.primary,
  themeData.secondary,
  themeData.accent,
  const Color(0xFF43A047), // green
  const Color(0xFFFB8C00), // orange
  const Color(0xFF00ACC1), // teal
];
