import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stories_list_screen.dart';
import 'characters_home_screen.dart';
import 'template_admin_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;

  @override
  void initState() {
    super.initState();
    AuthService().getUsername().then((value) {
      if (mounted) setState(() => _username = value);
    });
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
      body: Center(
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CharactersHomeScreen()),
                    );
                  },
                  icon: const Icon(Icons.people, size: 32),
                  label: const Text('New Story', style: TextStyle(fontSize: 20)),
                ),
              ),
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
          ),
        ),
      ),
    );
  }
}
