import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/book.dart';
import '../models/book_page.dart';
import '../models/character.dart';
import '../models/story_template.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

class ApiService {
  // Release builds (what actually gets deployed with `flutter build web`)
  // always talk to the real live server. Local `flutter run` testing talks
  // to your own machine instead - no more manual toggling before a deploy.
  static const String baseUrl = kReleaseMode
      ? 'https://api.storyfuntime.com'
      : 'https://localhost:7217';

  // The app's own public address (not the API) - used to build shareable
  // invite links like storyfuntime.com/go/?ref=username.
  static const String webAppUrl = kReleaseMode
      ? 'https://storyfuntime.com/go'
      : 'http://localhost:7217';

  final _authService = AuthService();

  /// Builds standard headers for an authenticated JSON request.
  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Just the Authorization header, for multipart requests (which set
  /// their own Content-Type).
  Future<Map<String, String>> _authOnlyHeader() async {
    final token = await _authService.getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// If the server says the session is no longer valid, clear the saved
  /// login and send the person back to the login screen.
  void _handleUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _authService.logout();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<String> transcribeAudio(Uint8List audioBytes) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/transcribe'); // adjust to your actual route
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'instructions.webm'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    return data['text'] as String; // adjust key to match your backend response shape
  }

  Future<Book> createBook({
    required String title,
    required String theme,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'title': title,
        'theme': theme,
      }),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 201) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create book: ${response.statusCode}');
    }
  }

  Future<List<Book>> getBooks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/books'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Book.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load books: ${response.statusCode}');
    }
  }

  Future<Book> getBook({required String id}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/books/$id'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load book: ${response.statusCode}');
    }
  }

  Future<Book> updateBook({required String bookId, required String title, required String theme}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/books/$bookId'),
      headers: await _authHeaders(),
      body: jsonEncode({'title': title, 'theme': theme}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update book: ${response.statusCode}');
    }
  }

  Future<List<String>> generateScript({
    required String bookId,
    int pageCount = 5,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/generate-script'),
      headers: await _authHeaders(),
      body: jsonEncode({'pageCount': pageCount}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['pages']);
    } else {
      throw Exception('Failed to generate script: ${response.statusCode}');
    }
  }

  Future<BookPage> addPage({
    required String bookId,
    required int pageNumber,
    required String scriptText,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/pages'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'pageNumber': pageNumber,
        'scriptText': scriptText,
        'originalPhotoUrl': null,
        'cartoonImageUrl': null,
        'audioUrl': null,
      }),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 201) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add page: ${response.statusCode}');
    }
  }

  Future<BookPage> uploadAudio({
    required String pageId,
    required List<int> audioBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/pages/$pageId/audio');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authOnlyHeader());
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: 'recording.webm'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to upload audio: ${response.statusCode}');
    }
  }

  Future<List<BookPage>> generateFromRecording({
    required String bookId,
    required List<int> audioBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/books/$bookId/generate-from-recording');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authOnlyHeader());
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: 'recording.webm'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((p) => BookPage.fromJson(p)).toList();
    } else {
      throw Exception('Failed to generate book from recording: ${response.statusCode} - ${response.body}');
    }
  }

  Future<BookPage> uploadPhoto({
    required String pageId,
    required List<int> photoBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/pages/$pageId/photo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authOnlyHeader());
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to upload photo: ${response.statusCode} ${response.body}');
    }
  }

  Future<Character> addCharacter({
    required String bookId,
    required String name,
    required String role,
    required String gender,
    String ageRange = '',
    String? extraInstructions,
    required List<int> photoBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/books/$bookId/characters');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authOnlyHeader());
    request.fields['name'] = name;
    request.fields['role'] = role;
    request.fields['gender'] = gender;
    request.fields['ageRange'] = ageRange;
    request.fields['extraInstructions'] = extraInstructions ?? '';
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _handleUnauthorized(response);
    if (response.statusCode == 201) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add character: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookPage> generateScene({required String pageId, String? extraInstructions}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/generate-scene'),
      headers: await _authHeaders(),
      body: jsonEncode({'extraInstructions': extraInstructions}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to generate scene: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteBook({required String bookId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/books/$bookId'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete book: ${response.statusCode}');
    }
  }

  Future<BookPage> updatePageText({required String pageId, required String scriptText}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/pages/$pageId'),
      headers: await _authHeaders(),
      body: jsonEncode({'scriptText': scriptText}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update page text: ${response.statusCode}');
    }
  }

  Future<BookPage> regeneratePageText({required String pageId, String? extraInstructions}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/regenerate-text'),
      headers: await _authHeaders(),
      body: jsonEncode({'extraInstructions': extraInstructions}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to regenerate text: ${response.statusCode}');
    }
  }

  Future<void> deleteCharacter({required String characterId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/characters/$characterId'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete character: ${response.statusCode}');
    }
  }

  Future<Character> regenerateCharacterAvatar({required String characterId, String? extraInstructions}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/regenerate-avatar'),
      headers: await _authHeaders(),
      body: jsonEncode({'extraInstructions': extraInstructions}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to regenerate avatar: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getAvatarHistory({required String characterId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/avatar-history'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load avatar history: ${response.statusCode}');
    }
  }

  Future<Character> selectAvatar({required String characterId, required String url}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/select-avatar'),
      headers: await _authHeaders(),
      body: jsonEncode({'url': url}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to select avatar: ${response.statusCode}');
    }
  }

  Future<Map<String, int>> getUserStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/stats'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'totalCharactersCreated': data['totalCharactersCreated'] as int,
        'totalCharactersDeleted': data['totalCharactersDeleted'] as int,
      };
    } else {
      throw Exception('Failed to load user stats: ${response.statusCode}');
    }
  }

  Future<void> deleteAvatarHistoryEntry({required String characterId, required String historyId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/characters/$characterId/avatar-history/$historyId'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete avatar: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> getLibraryBookId() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/library-book'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['bookId'] as String;
    } else {
      throw Exception('Failed to get library book: ${response.statusCode}');
    }
  }

  Future<List<Character>> getAllCharactersForUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/characters'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Character.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load characters: ${response.statusCode}');
    }
  }

  Future<void> copyCharactersToBook({required String bookId, required List<String> characterIds}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/characters/copy'),
      headers: await _authHeaders(),
      body: jsonEncode({'characterIds': characterIds}),
    );

    _handleUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to copy characters: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteAllPages({required String bookId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/books/$bookId/pages'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete pages: ${response.statusCode}');
    }
  }

  Future<BookPage> revertScene({required String pageId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/revert-scene'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to revert scene: ${response.statusCode}');
    }
  }

  // --- Story templates: shared/global data, not tied to one user ---

  Future<List<StoryTemplate>> getStoryTemplates() async {
    final response = await http.get(Uri.parse('$baseUrl/story-templates'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StoryTemplate.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load templates: ${response.statusCode}');
    }
  }

  Future<StoryTemplate> createStoryTemplate({required String title, required String theme}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/story-templates'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'theme': theme}),
    );
    if (response.statusCode == 201) {
      return StoryTemplate.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create template: ${response.statusCode}');
    }
  }

  Future<void> deleteStoryTemplate({required String templateId}) async {
    final response = await http.delete(Uri.parse('$baseUrl/story-templates/$templateId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete template: ${response.statusCode}');
    }
  }

  Future<StoryTemplatePage> addTemplatePage({required String templateId, required int pageNumber, required String templateText}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/story-templates/$templateId/pages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pageNumber': pageNumber, 'templateText': templateText}),
    );
    if (response.statusCode == 201) {
      return StoryTemplatePage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add template page: ${response.statusCode}');
    }
  }

  Future<StoryTemplatePage> updateTemplatePage({required String pageId, required String templateText}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/story-template-pages/$pageId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'templateText': templateText}),
    );
    if (response.statusCode == 200) {
      return StoryTemplatePage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update template page: ${response.statusCode}');
    }
  }

  Future<void> deleteTemplatePage({required String pageId}) async {
    final response = await http.delete(Uri.parse('$baseUrl/story-template-pages/$pageId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete template page: ${response.statusCode}');
    }
  }

  Future<void> applyTemplate({required String bookId, required String templateId, required Map<String, String> roleToCharacterId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/apply-template/$templateId'),
      headers: await _authHeaders(),
      body: jsonEncode({'roleToCharacterId': roleToCharacterId}),
    );
    _handleUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to apply template: ${response.statusCode} ${response.body}');
    }
  }

  Future<Book> generateVideo({required String bookId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/generate-video'),
      headers: await _authHeaders(),
    );
    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to generate video: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> createCheckoutSession({required String product}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/checkout-session'),
      headers: await _authHeaders(),
      body: jsonEncode({'product': product}),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['checkoutUrl'] as String;
    } else {
      throw Exception('Failed to start checkout: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getCredits() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/credits'),
      headers: await _authHeaders(),
    );

    _handleUnauthorized(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load credits: ${response.statusCode}');
    }
  }

}