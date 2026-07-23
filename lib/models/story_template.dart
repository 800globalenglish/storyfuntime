class StoryTemplate {
  final String id;
  final String title;
  final String theme;
  final List<StoryTemplatePage> pages;

  StoryTemplate({
    required this.id,
    required this.title,
    required this.theme,
    this.pages = const [],
  });

  factory StoryTemplate.fromJson(Map<String, dynamic> json) {
    return StoryTemplate(
      id: json['id'],
      title: json['title'],
      theme: json['theme'],
      pages: json['pages'] != null
          ? (json['pages'] as List)
              .map((p) => StoryTemplatePage.fromJson(p))
              .toList()
          : [],
    );
  }

  /// Finds every {roleName} placeholder used across all pages of this template.
  Set<String> get detectedRoles {
    final roles = <String>{};
    final pattern = RegExp(r'\{(\w+)\}');
    for (final page in pages) {
      for (final match in pattern.allMatches(page.templateText)) {
        roles.add(match.group(1)!);
      }
    }
    return roles;
  }
}

class StoryTemplatePage {
  final String id;
  final String storyTemplateId;
  final int pageNumber;
  final String templateText;

  StoryTemplatePage({
    required this.id,
    required this.storyTemplateId,
    required this.pageNumber,
    required this.templateText,
  });

  factory StoryTemplatePage.fromJson(Map<String, dynamic> json) {
    return StoryTemplatePage(
      id: json['id'],
      storyTemplateId: json['storyTemplateId'],
      pageNumber: json['pageNumber'],
      templateText: json['templateText'],
    );
  }
}
