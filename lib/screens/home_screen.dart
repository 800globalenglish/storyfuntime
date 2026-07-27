import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stories_list_screen.dart';
import 'characters_home_screen.dart';
import 'template_admin_screen.dart';
import 'login_screen.dart';
import 'add_character_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _authService.getUsername().then((value) {
      if (mounted) setState(() => _username = value);
    });
    _checkVerificationStatus();
    _loadHasBooks();
    _loadHasCharacters();
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
      MaterialPageRoute(builder: (context) => const CharactersHomeScreen()),
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
        MaterialPageRoute(builder: (context) => AddCharacterScreen(bookId: libraryBookId)),
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
          const SnackBar(content: Text('Verification email sent — check your inbox!')),
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

  void _copyUsername(BuildContext context) {
    if (_username == null) return;
    Clipboard.setData(ClipboardData(text: _username!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username copied — share it to invite a friend!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StoryFunTime'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showVerifyBanner)
            MaterialBanner(
              content: const Text('Please verify your email so you don\'t lose access to your stories.'),
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
                      : const Text('Resend email'),
                ),
                TextButton(
                  onPressed: () => setState(() => _showVerifyBanner = false),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/StoryFunTime_MainLogo.png',
                      height: 270,
                    ),
                    if (_username != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _copyUsername(context),
                        child: Chip(
                          avatar: const Icon(Icons.person_add_alt, size: 18),
                          label: Text('Invite friends with: $_username'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_hasBooks == null || _hasCharacters == null)
                      const CircularProgressIndicator()
                    else if (_hasBooks == false && _hasCharacters == false)
                      SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: ElevatedButton(
                          onPressed: _goToCreateFirstCharacter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Create First Character',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else if (_hasBooks == false)
                      SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: ElevatedButton(
                          onPressed: _goToNewStory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Create your first story',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 100,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StoriesListScreen()),
                              );
                            },
                            icon: const Icon(Icons.menu_book, size: 32),
                            label: const Text('Go to Stories', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 100,
                          child: ElevatedButton.icon(
                            onPressed: _goToNewStory,
                            icon: const Icon(Icons.people, size: 32),
                            label: const Text('New Story', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      ],
                    if (_hasBooks == true) ...[
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TemplateAdminScreen()),
                          );
                        },
                        child: const Text('Manage Story Templates'),
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