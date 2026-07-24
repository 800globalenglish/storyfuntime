import 'package:flutter/material.dart';
import 'stories_list_screen.dart';
import 'characters_home_screen.dart';
import 'template_admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StoryFunTime')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
