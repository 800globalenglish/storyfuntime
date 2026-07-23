import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../models/book_page.dart';
import '../models/character.dart';
import '../models/story_template.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5220';

  Future<Book> createBook({
    required String userId,
    required String title,
    required String theme,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'title': title,
        'theme': theme,
      }),
    );

    if (response.statusCode == 201) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create book: ${response.statusCode}');
    }
  }

  Future<List<Book>> getBooks({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/books?userId=$userId'),
    );

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
    );

    if (response.statusCode == 200) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load book: ${response.statusCode}');
    }
  }

  Future<List<String>> generateScript({
    required String bookId,
    int pageCount = 5,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/books/$bookId/generate-script'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pageCount': pageCount}),
    );

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pageNumber': pageNumber,
        'scriptText': scriptText,
        'originalPhotoUrl': null,
        'cartoonImageUrl': null,
        'audioUrl': null,
      }),
    );

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
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: 'recording.webm'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to upload audio: ${response.statusCode}');
    }
  }

  Future<BookPage> uploadPhoto({
    required String pageId,
    required List<int> photoBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/pages/$pageId/photo');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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

    if (response.statusCode == 201) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add character: ${response.statusCode} ${response.body}');
    }
  }

  Future<BookPage> generateScene({required String pageId, String? extraInstructions}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/generate-scene'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'extraInstructions': extraInstructions}),
    );

    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to generate scene: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteBook({required String bookId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/books/$bookId'),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete book: ${response.statusCode}');
    }
  }

  Future<BookPage> updatePageText({required String pageId, required String scriptText}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/pages/$pageId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'scriptText': scriptText}),
    );

    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update page text: ${response.statusCode}');
    }
  }

  Future<BookPage> regeneratePageText({required String pageId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/regenerate-text'),
    );

    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to regenerate text: ${response.statusCode}');
    }
  }

  Future<void> deleteCharacter({required String characterId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/characters/$characterId'),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete character: ${response.statusCode}');
    }
  }

  Future<Character> regenerateCharacterAvatar({required String characterId, String? extraInstructions}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/characters/$characterId/regenerate-avatar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'extraInstructions': extraInstructions}),
    );

    if (response.statusCode == 200) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to regenerate avatar: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getAvatarHistory({required String characterId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/characters/$characterId/avatar-history'),
    );

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode == 200) {
      return Character.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to select avatar: ${response.statusCode}');
    }
  }

  Future<Map<String, int>> getUserStats({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/stats'),
    );

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
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete avatar: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> getLibraryBookId({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/library-book'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['bookId'] as String;
    } else {
      throw Exception('Failed to get library book: ${response.statusCode}');
    }
  }

  Future<List<Character>> getAllCharactersForUser({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/characters'),
    );

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'characterIds': characterIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to copy characters: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteAllPages({required String bookId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/books/$bookId/pages'),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete pages: ${response.statusCode}');
    }
  }

  Future<BookPage> revertScene({required String pageId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pages/$pageId/revert-scene'),
    );

    if (response.statusCode == 200) {
      return BookPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to revert scene: ${response.statusCode}');
    }
  }

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'roleToCharacterId': roleToCharacterId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to apply template: ${response.statusCode} ${response.body}');
    }
  }
}
