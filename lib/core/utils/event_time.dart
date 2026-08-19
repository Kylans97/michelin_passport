import 'package:timezone/timezone.dart' as tz;

/// Events V2 Timezone Hardening — the ONE place in this app that converts
/// an Event's absolute instant (event.startAt/endAt — never touched by
/// `.toLocal()` since this hardening pass) into its own wall-clock
/// representation. Every Event-time consumer goes through this function —
/// display formatters in lib/features/events/event_date_format.dart, and
/// calendar-date comparisons like lib/models/event_trip_match.dart's
/// eventMatchesTrip — never `DateTime.toLocal()`, anywhere, for Event
/// time. Lives in core/utils (not features/events) specifically so a
/// dependency-free models-layer file like event_trip_match.dart can use it
/// without inverting the models → features layering. See
/// docs/Architecture/EVENTS_V2_TIMEZONE_HARDENING_PRE_APPLY.md for the
/// full rationale.
///
/// Falls back to UTC — never the device's own zone — when [timezone] is
/// null, empty, or not a real IANA identifier the bundled tzdata
/// recognizes (confirmed empirically: `tz.getLocation` throws for an
/// unrecognized identifier, exactly mirroring the database-side
/// `validate_event_timezone` trigger's own behavior). UTC is a stable,
/// viewer-independent fallback; silently substituting the device's zone
/// here would reintroduce the exact bug this module exists to close.
tz.TZDateTime eventLocalDateTime(DateTime instant, String? timezone) {
  if (timezone == null || timezone.isEmpty) {
    return tz.TZDateTime.from(instant, tz.UTC);
  }
  try {
    return tz.TZDateTime.from(instant, tz.getLocation(timezone));
  } catch (_) {
    return tz.TZDateTime.from(instant, tz.UTC);
  }
}
