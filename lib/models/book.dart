import 'book_page.dart';
import 'character.dart';

class Book {
  final String id;
  final String userId;
  final String title;
  final String theme;
  final String status;
  final String? videoUrl;
  final List<BookPage> pages;
  final List<Character> characters;

  Book({
    required this.id,
    required this.userId,
    required this.title,
    required this.theme,
    required this.status,
    this.videoUrl,
    this.pages = const [],
    this.characters = const [],
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      theme: json['theme'],
      status: json['status'],
      videoUrl: json['videoUrl'],
      pages: json['pages'] != null
          ? (json['pages'] as List)
          .map((p) => BookPage.fromJson(p))
          .toList()
          : [],
      characters: json['characters'] != null
          ? (json['characters'] as List)
          .map((c) => Character.fromJson(c))
          .toList()
          : [],
    );
  }
}
