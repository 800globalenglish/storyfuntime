import 'package:flutter/material.dart';

enum AppThemeKey { ocean, sunset, grape }

enum ButtonRole { primary, secondary, accent }

class AppThemeData {
  final String label;
  final Color primary;
  final Color secondary;
  final Color accent;
  const AppThemeData({required this.label, required this.primary, required this.secondary, required this.accent});
}

const Map<AppThemeKey, AppThemeData> kAppThemes = {
  AppThemeKey.ocean: AppThemeData(label: 'Ocean', primary: Color(0xFF1A8BC8), secondary: Color(0xFF136795), accent: Color(0xFF7F50B2)),
  AppThemeKey.sunset: AppThemeData(label: 'Sunset', primary: Color(0xFFE81E27), secondary: Color(0xFFEE575F), accent: Color(0xFF784AAA)),
  AppThemeKey.grape: AppThemeData(label: 'Grape', primary: Color(0xFF784AAA), secondary: Color(0xFF7F50B2), accent: Color(0xFF1A8BC8)),
};
