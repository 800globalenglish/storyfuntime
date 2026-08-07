enum StoryType {
  bedtime,
  adventure,
  sillyFunny,
  fairyTale,
  superhero,
  mystery,
  spaceAdventure,
  animalFriends,
  learning,
  ownTheme,
}

extension StoryTypeLabel on StoryType {
  String get label {
    switch (this) {
      case StoryType.bedtime:
        return 'Bedtime Story';
      case StoryType.adventure:
        return 'Adventure';
      case StoryType.sillyFunny:
        return 'Silly & Funny';
      case StoryType.fairyTale:
        return 'Fairy Tale';
      case StoryType.superhero:
        return 'Superhero';
      case StoryType.mystery:
        return 'Mystery';
      case StoryType.spaceAdventure:
        return 'Space Adventure';
      case StoryType.animalFriends:
        return 'Animal Friends';
      case StoryType.learning:
        return 'Learning Story';
      case StoryType.ownTheme:
        return 'Your own theme';
    }
  }

  // This string gets sent to the backend and should match whatever key/string
  // the backend prompt-building code expects to switch on.
  String get apiValue => name;
}
