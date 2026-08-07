import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/stories_list_screen.dart';
import '../screens/characters_home_screen.dart';
import '../screens/add_character_screen.dart';
import '../screens/template_admin_screen.dart';
import '../screens/credits_screen.dart';
import '../screens/my_invites_screen.dart';
import '../screens/language_settings_screen.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/app_strings.dart';
import '../utils/fade_route.dart';

enum _NavDestination {
  home,
  stories,
  newStory,
  characters,
  templates,
  credits,
  invites,
  language,
  appearance,
  logout,
}

/// The red "..." menu shown in every authenticated screen's app bar,
/// giving a way to jump to any other part of the app from wherever
/// the person currently is.
class AppNavMenuButton extends StatelessWidget {
  const AppNavMenuButton({super.key});

  Future<void> _goToMyCharacters(BuildContext context) async {
    try {
      final libraryBookId = await ApiService().getLibraryBookId();
      if (!context.mounted) return;
      Navigator.push(
        context,
        FadeRoute(page: AddCharacterScreen(bookId: libraryBookId)),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load characters: $e')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      FadeRoute(page: const LoginScreen()),
          (route) => false,
    );
  }

  void _handleSelection(BuildContext context, _NavDestination destination) {
    switch (destination) {
      case _NavDestination.home:
        Navigator.of(context).pushAndRemoveUntil(
          FadeRoute(page: const HomeScreen()),
              (route) => false,
        );
        break;
      case _NavDestination.stories:
        Navigator.push(context, FadeRoute(page: const StoriesListScreen()));
        break;
      case _NavDestination.newStory:
        Navigator.push(context, FadeRoute(page: const CharactersHomeScreen()));
        break;
      case _NavDestination.characters:
        _goToMyCharacters(context);
        break;
      case _NavDestination.templates:
        Navigator.push(context, FadeRoute(page: const TemplateAdminScreen()));
        break;
      case _NavDestination.credits:
        Navigator.push(context, FadeRoute(page: const CreditsScreen()));
        break;
      case _NavDestination.invites:
        Navigator.push(context, FadeRoute(page: const MyInvitesScreen()));
        break;
      case _NavDestination.language:
        Navigator.push(context, FadeRoute(page: const LanguageSettingsScreen()));
        break;
      case _NavDestination.appearance:
        Navigator.push(context, FadeRoute(page: const AppearanceSettingsScreen()));
        break;
      case _NavDestination.logout:
        _logout(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_NavDestination>(
      tooltip: AppStrings.t('get_around_tooltip'),
      onSelected: (destination) => _handleSelection(context, destination),
      icon: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFE81E27),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _NavDestination.home,
          child: Row(children: [const Icon(Icons.home), const SizedBox(width: 12), Text(AppStrings.t('nav_home'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.stories,
          child: Row(children: [const Icon(Icons.menu_book), const SizedBox(width: 12), Text(AppStrings.t('nav_my_stories'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.newStory,
          child: Row(children: [const Icon(Icons.people), const SizedBox(width: 12), Text(AppStrings.t('nav_new_story'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.characters,
          child: Row(children: [const Icon(Icons.face), const SizedBox(width: 12), Text(AppStrings.t('nav_my_characters'))]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _NavDestination.templates,
          child: Row(children: [const Icon(Icons.auto_stories), const SizedBox(width: 12), Text(AppStrings.t('nav_manage_templates'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.credits,
          child: Row(children: [const Icon(Icons.add_circle_outline), const SizedBox(width: 12), Text(AppStrings.t('nav_buy_credits'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.invites,
          child: Row(children: [const Icon(Icons.person_add_alt), const SizedBox(width: 12), Text(AppStrings.t('nav_invite_friends'))]),
        ),
        PopupMenuItem(
          value: _NavDestination.language,
          child: Row(children: [const Icon(Icons.language), const SizedBox(width: 12), Text(AppStrings.t('nav_language_settings'))]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _NavDestination.logout,
          child: Row(children: [const Icon(Icons.logout, color: Colors.red), const SizedBox(width: 12), Text(AppStrings.t('nav_log_out'), style: const TextStyle(color: Colors.red))]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _NavDestination.appearance,
          child: Row(children: [const Icon(Icons.palette_outlined), const SizedBox(width: 12), Text(AppStrings.t('nav_appearance'))]),
        ),
      ],
    );
  }
}
