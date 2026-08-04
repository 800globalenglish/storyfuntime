import 'dart:async';
import 'package:flutter/material.dart';
import 'stories_list_screen.dart';
import 'characters_home_screen.dart';
import 'template_admin_screen.dart';
import 'login_screen.dart';
import 'add_character_screen.dart';
import 'my_invites_screen.dart';
import 'language_settings_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../screens/credits_screen.dart';
import '../utils/fade_route.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// How long a new, unverified account gets to explore before the
/// reminder banner shows up.
const _verificationGracePeriod = Duration(minutes: 5);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _apiService = ApiService();

  String? _username;
  bool _showVerifyBanner = false;
  bool _isSendingEmail = false;
  Timer? _bannerTimer;
  bool? _hasBooks;
  bool? _hasCharacters;
  int? _totalCredits; // creditBalance + bonusCredits combined, for the "low" check

  static const _buttonRadius = BorderRadius.all(Radius.circular(10));
  static const _buttonHeight = 71.0;

  @override
  void initState() {
    super.initState();
    _authService.getUsername().then((value) {
      if (mounted) setState(() => _username = value);
    });
    _checkVerificationStatus();
    _loadHasBooks();
    _loadHasCharacters();
    _loadCredits();
    // Rebuild this screen whenever the language changes elsewhere in the app.
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  Future<void> _loadCredits() async {
    try {
      final credits = await _apiService.getCredits();
      if (mounted) {
        setState(() {
          _totalCredits = (credits['creditBalance'] as int) + (credits['bonusCredits'] as int);
        });
      }
    } catch (e) {
      // Non-critical - if this fails, the Buy Credits button just won't show.
      // Don't block the rest of the home screen over it.
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  String _languageFlag() {
    final code = AppStrings.languageCode.value;
    return supportedLanguages
        .firstWhere((language) => language.code == code, orElse: () => supportedLanguages.first)
        .flag;
  }

  Future<void> _loadHasBooks() async {
    try {
      final books = await _apiService.getBooks();
      if (mounted) setState(() => _hasBooks = books.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasBooks = true);
    }
  }

  Future<void> _loadHasCharacters() async {
    try {
      final characters = await _apiService.getAllCharactersForUser();
      if (mounted) setState(() => _hasCharacters = characters.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasCharacters = true);
    }
  }

  Future<void> _goToNewStory() async {
    await Navigator.push(
      context,
      FadeRoute(page: const CharactersHomeScreen()),
    );
    _loadHasBooks();
    _loadHasCharacters();
  }

  /// For a brand-new account with no characters yet at all - skips straight
  /// into creating the first one, instead of landing on a Characters screen
  /// that would just show its own "create first character" button.
  Future<void> _goToCreateFirstCharacter() async {
    try {
      final libraryBookId = await _apiService.getLibraryBookId();
      if (!mounted) return;
      await Navigator.push(
        context,
        FadeRoute(page: AddCharacterScreen(bookId: libraryBookId)),
      );
      _loadHasBooks();
      _loadHasCharacters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    // Ask the server in case the person already clicked the email link
    // in a previous session.
    final verified = await _authService.refreshVerificationStatus();
    if (verified) return;

    final createdAt = await _authService.getCreatedAt();
    if (createdAt == null) return;

    final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
    final remaining = _verificationGracePeriod - elapsed;

    if (remaining <= Duration.zero) {
      if (mounted) setState(() => _showVerifyBanner = true);
    } else {
      _bannerTimer = Timer(remaining, () {
        if (mounted) setState(() => _showVerifyBanner = true);
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isSendingEmail = true);
    try {
      await _authService.resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('verification_email_sent'))),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }
  Future<void> _goToMyCharacters() async {
    try {
      final libraryBookId = await _apiService.getLibraryBookId();
      if (!mounted) return;
      await Navigator.push(
        context,
        FadeRoute(page: AddCharacterScreen(bookId: libraryBookId)),
      );
      _loadHasBooks();
      _loadHasCharacters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load characters: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('home_screen.dart'),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Text(_languageFlag(), style: const TextStyle(fontSize: 22)),
            tooltip: 'Language',
            onPressed: () {
              Navigator.push(
                context,
                FadeRoute(page: const LanguageSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.t('log_out_tooltip'),
            onPressed: () => _logout(context),
          ),
          const AppNavMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_showVerifyBanner)
            MaterialBanner(
              content: Text(AppStrings.t('verify_email_banner')),
              leading: const Icon(Icons.mark_email_unread_outlined),
              actions: [
                TextButton(
                  onPressed: _isSendingEmail ? null : _resendVerificationEmail,
                  child: _isSendingEmail
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(AppStrings.t('resend_email')),
                ),
                TextButton(
                  onPressed: () => setState(() => _showVerifyBanner = false),
                  child: Text(AppStrings.t('dismiss')),
                ),
              ],
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/StoryFunTime_MainLogo.png',
                      height: 270,
                    ),
                    if (_username != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            FadeRoute(page: const MyInvitesScreen()),
                          );
                        },
                        child: Chip(
                          avatar: const Icon(Icons.person_add_alt, size: 18),
                          label: Text('${AppStrings.t('invite_friends_with')} $_username'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ValueListenableBuilder<AppThemeKey>(
                      valueListenable: ThemeController.instance.current,
                      builder: (context, themeKey, _) {
                        final themeData = kAppThemes[themeKey]!;
                        if (_hasBooks == null || _hasCharacters == null) {
                          return const CircularProgressIndicator();
                        } else if (_hasBooks == false && _hasCharacters == false) {
                          return SizedBox(
                            width: double.infinity,
                            height: _buttonHeight,
                            child: ElevatedButton(
                              onPressed: _goToCreateFirstCharacter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeData.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                              ),
                              child: Text(
                                AppStrings.t('create_first_character'),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        } else if (_hasBooks == false) {
                          return SizedBox(
                            width: double.infinity,
                            height: _buttonHeight,
                            child: ElevatedButton(
                              onPressed: _goToNewStory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeData.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                              ),
                              child: Text(
                                AppStrings.t('create_your_first_story'),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    FadeRoute(page: const StoriesListScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeData.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                                ),
                                icon: const Icon(Icons.menu_book, size: 32),
                                label: Text(AppStrings.t('go_to_stories'), style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: _goToNewStory,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeData.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                                ),
                                icon: const Icon(Icons.people, size: 32),
                                label: Text(AppStrings.t('new_story'), style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: _goToMyCharacters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeData.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
                                ),
                                icon: const Icon(Icons.face, size: 32),
                                label: Text(AppStrings.t('Add Characters'), style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_hasBooks == true) ...[
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            FadeRoute(page: const TemplateAdminScreen()),
                          );
                        },
                        child: Text(AppStrings.t('manage_story_templates')),
                      ),
                    ],
                    if (_totalCredits != null && _totalCredits! < 20) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            FadeRoute(page: const CreditsScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(AppStrings.t('buy_credits')),
                      ),

                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
