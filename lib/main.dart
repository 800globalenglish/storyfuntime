import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/dev_menu_screen.dart';
import 'services/auth_service.dart';
import 'services/app_strings.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Captured from a shared invite link like storyfuntime.com/go/?ref=username.
/// Read once at startup and used to pre-fill the signup form.
String? pendingReferralUsername;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pendingReferralUsername = Uri.base.queryParameters['ref'];
  await AppStrings.init();
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
      // TEMPORARY: dev-only deep link for QA, see dev_menu_screen.dart.
      routes: {
        '/debug': (context) => const DevMenuScreen(),
      },
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
              child: LanguageAware(child: child!),
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
    // A password reset link takes priority over the normal login-check flow,
    // whether or not the person happens to be logged in on this device.
    final resetToken = Uri.base.queryParameters['resetToken'];
    if (resetToken != null && resetToken.isNotEmpty) {
      return ResetPasswordScreen(token: resetToken);
    }

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