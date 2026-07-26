import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// Handles account creation, login, and remembering who's signed in.
///
/// The token and userId are saved to the device's secure storage
/// (Keychain on iOS, Keystore on Android) so the person stays logged in
/// between app launches.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _emailKey = 'auth_email';
  static const _usernameKey = 'auth_username';

  /// Creates a new account and logs the person in.
  /// [referredByUsername] is optional — if it matches an existing
  /// account, that person is credited as the referrer.
  /// Throws an [AuthException] with a friendly message on failure.
  Future<void> signup({
    required String email,
    required String username,
    required String password,
    String? referredByUsername,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
        'referredByUsername': referredByUsername,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _saveSession(data);
      return;
    }

    throw AuthException(_messageFor(response));
  }

  /// Logs an existing person in using their email OR username.
  /// Throws an [AuthException] with a friendly message on failure.
  Future<void> login({required String emailOrUsername, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emailOrUsername': emailOrUsername, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveSession(data);
      return;
    }

    throw AuthException(_messageFor(response));
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _storage.write(key: _tokenKey, value: data['token'] as String);
    await _storage.write(key: _userIdKey, value: data['userId'] as String);
    await _storage.write(key: _emailKey, value: data['email'] as String);
    await _storage.write(key: _usernameKey, value: data['username'] as String);
  }

  String _messageFor(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] is String) return data['error'] as String;
    } catch (_) {
      // Response body wasn't JSON - fall through to the generic message below.
    }
    if (response.statusCode == 409) return 'That email or username is already taken.';
    if (response.statusCode == 401) return 'Incorrect email/username or password.';
    return 'Something went wrong. Please try again.';
  }

  /// Clears the saved session. The person will need to log in again.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _usernameKey);
  }

  /// The signed-in person's user ID, or null if nobody is logged in.
  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  /// The signed-in person's email, or null if nobody is logged in.
  Future<String?> getEmail() => _storage.read(key: _emailKey);

  /// The signed-in person's username, or null if nobody is logged in.
  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  /// The raw JWT to attach to authenticated API calls, or null if
  /// nobody is logged in.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// True if there's a saved session.
  Future<bool> isLoggedIn() async => (await getToken()) != null;
}

/// A signup/login failure with a message safe to show directly to the user.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
