class Character {
  final String id;
  final String bookId;
  final String name;
  final String role;
  final String? originalPhotoUrl;
  final String? cartoonAvatarUrl;

  Character({
    required this.id,
    required this.bookId,
    required this.name,
    required this.role,
    this.originalPhotoUrl,
    this.cartoonAvatarUrl,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      bookId: json['bookId'],
      name: json['name'],
      role: json['role'],
      originalPhotoUrl: json['originalPhotoUrl'],
      cartoonAvatarUrl: json['cartoonAvatarUrl'],
    );
  }
}
