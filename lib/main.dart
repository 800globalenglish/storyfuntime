import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const StoryFunTimeApp());
}

class StoryFunTimeApp extends StatelessWidget {
  const StoryFunTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'StoryFunTime',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Container(
          color: const Color(0xFF800000),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Shown first on every app launch. Checks whether there's a saved
/// login, then sends the person to the right place.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/StoryFunTime_MainLogo.png',
                    height: 300,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        final loggedIn = snapshot.data ?? false;
        return loggedIn ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}