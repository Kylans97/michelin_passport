/// Client-side mirror of `profiles_username_format` (Social Foundation
/// Step 1 migration) — for immediate form feedback only. The database
/// constraint is the actual authority; this exists so a user sees
/// "3-30 characters..." before they submit, not only after a round trip.
///
/// Rule: 3-30 characters, lowercase letters/digits/`_`/`.` only, must
/// start and end with a letter or digit, no two punctuation characters
/// in a row.
class UsernameRules {
  UsernameRules._();

  static final RegExp _pattern = RegExp(r'^[a-z0-9]([a-z0-9]|[_.][a-z0-9])*$');

  /// Lowercases and trims — the canonical form the database actually
  /// stores. Call this before validating/submitting, not after.
  static String normalize(String input) => input.trim().toLowerCase();

  /// Returns a user-facing error message, or null if [normalized] (already
  /// [normalize]d) satisfies the rule.
  static String? validate(String normalized) {
    if (normalized.isEmpty) return 'Choose a username';
    if (normalized.length < 3 || normalized.length > 30) {
      return 'Usernames are 3–30 characters';
    }
    if (!_pattern.hasMatch(normalized)) {
      return 'Lowercase letters, numbers, "_" and "." only — '
          'must start and end with a letter or number';
    }
    return null;
  }

  static const _plain = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', //
    'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', //
    'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u', //
    'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss', 'æ': 'ae', //
    'œ': 'oe',
  };

  /// Usernames made from a display name, best first, each one valid: for
  /// "Elise Laurent", elise.laurent, eliselaurent, elise.l and elaurent.
  /// Accents are dropped and a family name of several words is joined
  /// ("Van den Broeck" gives vandenbroeck). Availability is not checked
  /// here; the caller asks the database.
  static List<String> suggestionsFor(String name) {
    final words = name
        .toLowerCase()
        .split('')
        .map((c) => _plain[c] ?? c)
        .join()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final first = words.first;
    final last = words.skip(1).join();
    final candidates = last.isEmpty
        ? [first]
        : [
            '$first.$last',
            '$first$last',
            '$first.${last[0]}',
            '${first[0]}$last',
          ];
    final seen = <String>{};
    return [
      for (final c in candidates)
        if (validate(c) == null && seen.add(c)) c,
    ];
  }
}
