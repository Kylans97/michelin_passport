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
}
