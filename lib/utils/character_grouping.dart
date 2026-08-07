import '../models/character.dart';

/// One entry per unique avatar. If the same person appears in several books,
/// [count] reflects how many, and [representative] is whichever Character
/// record is shown/selected - any of them clones the same name/avatar into a
/// target book via copyCharactersToBook, so it doesn't matter which one.
class CharacterGroup {
  final Character representative;
  final int count;

  CharacterGroup({required this.representative, required this.count});
}

/// Groups characters by cartoon avatar (characters reused across multiple
/// books share one tile with a story-count badge). Characters with no avatar
/// yet are never grouped together with each other.
List<CharacterGroup> groupCharacters(List<Character> characters) {
  final Map<String, List<Character>> groups = {};
  for (final c in characters) {
    final key = c.cartoonAvatarUrl ?? 'ungrouped-${c.id}';
    groups.putIfAbsent(key, () => []).add(c);
  }
  return groups.values
      .map((group) => CharacterGroup(representative: group.first, count: group.length))
      .toList();
}
