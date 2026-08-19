/// Builds a machine-safe `tel:` URI from a stored, human-readable phone
/// number (e.g. `"+31 (0)10 436 07 66"`) — the single canonical
/// representation a venue's `phone` column holds. Strips everything except
/// a leading `+` and digits, preserving the international dialing prefix;
/// the human-readable spacing/parentheses stay in the stored value for
/// display and are only stripped here, at call time, never written back.
///
/// `(0)` is dropped as a literal substring before digit-extraction: it's
/// the standard European "national trunk prefix" notation (also common for
/// DE/UK/FR numbers, not specific to NL) meaning "dial this 0 for domestic
/// calls, omit it when dialing with the country code." It is only ever
/// this exact bare-zero form, so it's distinguishable from a real area
/// code in parens (e.g. US-style `(212)`), which is left untouched.
///
/// Returns null when [phone] has no dialable digits at all — nothing safe
/// to construct a URI from — so a caller can treat that the same as "no
/// phone" rather than risking a bare `tel:` with nothing after it.
Uri? buildTelUri(String phone) {
  final withoutTrunkNotation = phone.replaceAll('(0)', '');
  final buffer = StringBuffer();
  for (var i = 0; i < withoutTrunkNotation.length; i++) {
    final char = withoutTrunkNotation[i];
    if (char == '+' && buffer.isEmpty) {
      buffer.write(char);
    } else if (RegExp(r'[0-9]').hasMatch(char)) {
      buffer.write(char);
    }
  }
  final sanitized = buffer.toString();
  if (sanitized.isEmpty || sanitized == '+') return null;
  return Uri.parse('tel:$sanitized');
}
