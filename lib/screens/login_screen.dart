import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/app_strings.dart';
import '../main.dart';
import 'home_screen.dart';
import 'language_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _referredByController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isSignupMode = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Arriving via a shared invite link (storyfuntime.com/go/?ref=username) -
    // pre-fill it and go straight into signup mode.
    if (pendingReferralUsername != null && pendingReferralUsername!.isNotEmpty) {
      _referredByController.text = pendingReferralUsername!;
      _isSignupMode = true;
    }
    // Rebuild this screen whenever the language changes elsewhere in the app.
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    _emailController.dispose();
    _usernameController.dispose();
    _referredByController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isSignupMode) {
        await _authService.signup(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          referredByUsername: _referredByController.text.trim().isEmpty
              ? null
              : _referredByController.text.trim(),
        );
      } else {
        await _authService.login(
          emailOrUsername: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = AppStrings.t('could_not_reach_server'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Language',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/StoryFunTime_MainLogo.png',
                    height: 300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSignupMode ? AppStrings.t('create_account_title') : AppStrings.t('welcome_back'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: _isSignupMode ? TextInputType.emailAddress : TextInputType.text,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _isSignupMode ? AppStrings.t('email_label') : AppStrings.t('email_or_username_label'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _isSignupMode ? AppStrings.t('please_enter_email') : AppStrings.t('please_enter_email_or_username');
                      }
                      if (_isSignupMode && !value.contains('@')) return AppStrings.t('please_enter_valid_email');
                      return null;
                    },
                  ),
                  if (_isSignupMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: AppStrings.t('username_label'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return AppStrings.t('please_choose_username');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referredByController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: AppStrings.t('invited_by_label'),
                        hintText: AppStrings.t('invited_by_hint'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.t('password_label'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppStrings.t('please_enter_password');
                      if (_isSignupMode && value.length < 8) return AppStrings.t('password_min_length');
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                          : Text(
                        _isSignupMode ? AppStrings.t('create_account_button') : AppStrings.t('log_in_button'),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                      setState(() {
                        _isSignupMode = !_isSignupMode;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignupMode
                          ? AppStrings.t('already_have_account')
                          : AppStrings.t('new_here'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
