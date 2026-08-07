import 'package:flutter/material.dart';

Color _autoTextColorFor(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

class AppBackgroundData {
  final String label;
  final Color? color;
  final Color? titleTextColorOverride;
  final Color? bodyTextColorOverride;
  final Color? primaryOverride;
  final Color? secondaryOverride;
  final Color? accentOverride;
  final Color? primaryTextOverride;
  final Color? secondaryTextOverride;
  final Color? accentTextOverride;

  const AppBackgroundData({
    required this.label,
    required this.color,
    this.titleTextColorOverride,
    this.bodyTextColorOverride,
    this.primaryOverride,
    this.secondaryOverride,
    this.accentOverride,
    this.primaryTextOverride,
    this.secondaryTextOverride,
    this.accentTextOverride,
  });

  Color? get titleTextColor {
    if (titleTextColorOverride != null) return titleTextColorOverride;
    if (color == null) return null;
    return _autoTextColorFor(color!);
  }

  Color? get bodyTextColor {
    if (bodyTextColorOverride != null) return bodyTextColorOverride;
    if (color == null) return null;
    return titleTextColor!.withValues(alpha: 0.85);
  }
}

enum AppBackgroundKey { original, coralRed, amber, green, teal, skyBlue, purple, pink, orange, charcoal }

const Map<AppBackgroundKey, AppBackgroundData> kAppBackgrounds = {
  AppBackgroundKey.original: AppBackgroundData(
    label: 'Default',
    color: null,
  ),
  AppBackgroundKey.coralRed: AppBackgroundData(
    label: 'Coral Red',
    color: Color(0xFFE24B4A),
  ),
  AppBackgroundKey.amber: AppBackgroundData(
    label: 'Amber',
    color: Color(0xFFBA7517),
    titleTextColorOverride: Color(0xFF412402),
    bodyTextColorOverride: Color(0xFF633806),
  ),
  AppBackgroundKey.green: AppBackgroundData(
    label: 'Green',
    color: Color(0xFF639922),
    titleTextColorOverride: Color(0xFF173404),
    bodyTextColorOverride: Color(0xFF27500A),
  ),
  AppBackgroundKey.teal: AppBackgroundData(
    label: 'Teal',
    color: Color(0xFF1D9E75),
  ),
  AppBackgroundKey.skyBlue: AppBackgroundData(
    label: 'Sky Blue',
    color: Color(0xFF378ADD),
    accentOverride: Color(0xFF412402),
  ),
  AppBackgroundKey.purple: AppBackgroundData(
    label: 'Purple',
    color: Color(0xFF534AB7),
    accentOverride: Color(0xFFFAEEDA),
    accentTextOverride: Color(0xFF412402),
  ),
  AppBackgroundKey.pink: AppBackgroundData(
    label: 'Pink',
    color: Color(0xFFD4537E),
    accentOverride: Color(0xFF26215C),
  ),
  AppBackgroundKey.orange: AppBackgroundData(
    label: 'Orange',
    color: Color(0xFFD85A30),
    accentOverride: Color(0xFF26215C),
  ),
  AppBackgroundKey.charcoal: AppBackgroundData(
    label: 'Charcoal',
    color: Color(0xFF444441),
  ),
};
