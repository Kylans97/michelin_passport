// Events V2 Step 4 §5 — "Not now" on the Events screen's own unprompted
// top-card nudge. Deliberately the smallest possible mechanism: a plain
// in-memory set, reset automatically on every cold app start (a static
// field, not persisted anywhere) — no SharedPreferences/local-db
// dependency added solely for a temporary dismissal, no notification/
// reminder infrastructure. "Dismissed for the current session" per §5's
// own menu of acceptable MVP rules.
//
// Deliberately scoped to ONLY the Events screen's ambient/unprompted
// surface — Event Detail's own inline prompt (an explicit navigation the
// user chose) never consults this; dismissing a passive nudge should never
// block an explicit action screen. See AttendancePromptDismissal's own
// call site in events_screen.dart for where this distinction is applied.
class AttendancePromptDismissal {
  AttendancePromptDismissal._();

  static final Set<String> _dismissedEventIds = {};

  static bool isDismissed(String eventId) =>
      _dismissedEventIds.contains(eventId);

  static void dismiss(String eventId) => _dismissedEventIds.add(eventId);
}
