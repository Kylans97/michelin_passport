import 'passport_stamp_style.dart' show stampStableHash;

/// PLACEHOLDER — `public.profiles` has no member-number column today (see
/// EDITORIAL_REDESIGN_TRACKING.md's "New backend needs"). Never persisted,
/// never sent anywhere, and not a claim that this is the user's real
/// assigned number — only that "MEMBER NO." and the passport data page's
/// MRZ strip have *something* stable to show instead of blocking the
/// whole screen on a migration that hasn't been asked for. Deterministic
/// from [userId] via the same stable hash the stamp system itself already
/// uses, so it stays constant across reloads within one account. Replace
/// every call site the moment a real `member_number` column exists.
String derivedMemberNumberPlaceholder(String userId) {
  final n = stampStableHash('$userId:member') % 900000 + 100000;
  return '$n';
}
