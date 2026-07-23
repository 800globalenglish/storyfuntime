class BookPage {
  final String id;
  final String bookId;
  final int pageNumber;
  final String scriptText;
  final String? originalPhotoUrl;
  final String? cartoonImageUrl;
  final String? previousCartoonImageUrl;
  final String? audioUrl;

  BookPage({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    required this.scriptText,
    this.originalPhotoUrl,
    this.cartoonImageUrl,
    this.previousCartoonImageUrl,
    this.audioUrl,
  });

  factory BookPage.fromJson(Map<String, dynamic> json) {
    return BookPage(
      id: json['id'],
      bookId: json['bookId'],
      pageNumber: json['pageNumber'],
      scriptText: json['scriptText'],
      originalPhotoUrl: json['originalPhotoUrl'],
      cartoonImageUrl: json['cartoonImageUrl'],
      previousCartoonImageUrl: json['previousCartoonImageUrl'],
      audioUrl: json['audioUrl'],
    );
  }
}
