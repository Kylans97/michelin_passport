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
  return tz.TZDateTime.from(instant, _location(timezone));
}

tz.Location _location(String? timezone) {
  if (timezone == null || timezone.isEmpty) return tz.UTC;
  try {
    return tz.getLocation(timezone);
  } catch (_) {
    return tz.UTC;
  }
}

/// Events V2 Time Precision Phase B — compares two "calendar date only"
/// values purely by their (year, month, day) components, deliberately
/// ignoring whatever zone tag either [DateTime] happens to carry.
///
/// [Event.startDate]/[endDate] are always constructed as UTC-tagged,
/// midnight-zeroed values (see event.dart); [PlannedTrip.startDate]/
/// [endDate] are parsed via a bare `DateTime.parse` of a date-only string,
/// which Dart resolves to the DEVICE's local zone, not UTC (an existing,
/// pre-Phase-B characteristic of `PlannedTrip`, out of this phase's scope
/// to change). Comparing two such values with `DateTime.isAfter`/
/// `.isBefore`/`.compareTo` directly would silently compare absolute
/// instants — which, for two midnight values tagged in different zones,
/// are NOT the same moment, and the difference is exactly the device's own
/// UTC offset leaking into a calendar-date comparison. This function
/// exists specifically to make that class of bug structurally impossible:
/// it never looks at the instant, only the calendar fields, so it produces
/// the identical, correct answer no matter which zone either input was
/// constructed against.
int compareCalendarDates(DateTime a, DateTime b) {
  final byYear = a.year.compareTo(b.year);
  if (byYear != 0) return byYear;
  final byMonth = a.month.compareTo(b.month);
  if (byMonth != 0) return byMonth;
  return a.day.compareTo(b.day);
}

/// The instant an Event is considered to have fully ended, for both
/// lifecycle checks ([eventHasEnded]) and any window computed FROM that
/// end point (e.g. the Attendance-prompt lookback). Exact-instant fast
/// path when [endAt] is known (unchanged behavior — every one of today's
/// full-precision Events, and every existing regression test, resolves
/// through this branch exactly as before Phase B). When [endAt] is
/// unknown, resolves to the first instant AFTER [endDate]'s local day has
/// fully elapsed in [timezone] — i.e. local midnight at the START of the
/// day following [endDate], converted back to a real instant via the
/// timezone package's own DST-aware `TZDateTime` constructor (never manual
/// "+24 hours" arithmetic, which is wrong on a 23- or 25-hour local day).
/// Never materializes or stores a fake `23:59:59`/`00:00:00` — this is
/// computed fresh every call, exactly the "central, precision-aware layer"
/// the architecture audit requires every lifecycle/window decision to go
/// through.
DateTime eventEndReferenceInstant({
  required DateTime? endAt,
  required DateTime endDate,
  required String? timezone,
}) {
  if (endAt != null) return endAt;
  final loc = _location(timezone);
  final startOfDayAfterEnd = tz.TZDateTime(
    loc,
    endDate.year,
    endDate.month,
    endDate.day + 1,
  );
  return startOfDayAfterEnd.toUtc();
}

/// Whether an Event has definitively ended as of [now] — the one
/// centralized, precision-aware lifecycle check every consumer
/// (`canAttendEvent`, Attendance eligibility, etc.) reads instead of
/// re-deriving its own `endAt`-only rule. Exact instant when known;
/// local-day-boundary of `endDate` otherwise (see
/// [eventEndReferenceInstant]).
bool eventHasEnded({
  required DateTime? endAt,
  required DateTime endDate,
  required String? timezone,
  required DateTime now,
}) => !eventEndReferenceInstant(
  endAt: endAt,
  endDate: endDate,
  timezone: timezone,
).isAfter(now);
