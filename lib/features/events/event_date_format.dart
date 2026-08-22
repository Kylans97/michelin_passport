import '../../core/utils/event_time.dart';
import '../../models/event.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Compact date range for cards/list contexts — "27–30 Aug 2026" for a
/// multi-day event, "27 Aug 2026" for a single-day one — in the event's
/// OWN timezone, never the viewer's device zone.
///
/// Events V2 Time Precision Phase B: reads [Event.startDate]/[endDate]
/// directly (already the event's own correct local calendar dates, per
/// Phase A's backfill/derivation — see event.dart) rather than deriving
/// them here from [Event.startAt]/[endAt] via [eventLocalDateTime]. This
/// is a behavior-PRESERVING change for every full-precision Event
/// (identical output, since [Event.startDate]/[endDate] are computed from
/// exactly the same instants this function used to truncate itself) that
/// also makes this formatter safe for a date-only Event, which may have
/// null [Event.startAt]/[endAt] entirely.
String formatEventDateRange(Event event) {
  final s = event.startDate;
  final e = event.endDate;
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  if (sameDay) {
    return '${s.day} ${_monthNames[s.month - 1]} ${s.year}';
  }
  if (s.year == e.year && s.month == e.month) {
    return '${s.day}–${e.day} ${_monthNames[s.month - 1]} ${s.year}';
  }
  if (s.year == e.year) {
    return '${s.day} ${_monthNames[s.month - 1]} – ${e.day} '
        '${_monthNames[e.month - 1]} ${s.year}';
  }
  return '${s.day} ${_monthNames[s.month - 1]} ${s.year} – ${e.day} '
      '${_monthNames[e.month - 1]} ${e.year}';
}

/// Full date + time for Event Detail — "Thu 27 Aug 2026, 18:00" — in
/// [timezone], never the viewer's device zone. [instant] is always
/// event.startAt or event.endAt (an absolute instant); [timezone] is
/// always event.timezone.
String formatEventDateTime(DateTime instant, String? timezone) {
  final date = eventLocalDateTime(instant, timezone);
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = weekdays[date.weekday - 1];
  return '$weekday ${date.day} ${_monthNames[date.month - 1]} ${date.year}, '
      '${_pad2(date.hour)}:${_pad2(date.minute)}';
}

/// Events V2 Time Precision Phase B — the one canonical combined date+time
/// string, honoring exactly the precision actually known
/// (EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md's own Display Rules):
///
/// - date only (no time known at all):      `"29 Sep 2026"`
/// - multi-day, date only:                  `"25–27 Sep 2026"`
/// - start known, end unknown:              `"29 Sep 2026 · 18:30"`
/// - full, single day:                      `"29 Sep 2026 · 18:30–23:00"`
/// - full, multi-day:                       `"25–27 Sep 2026 · 18:30–23:00"`
///   (the date range itself is [formatEventDateRange]'s own unchanged
///   output — only a start/end time suffix is ever added)
///
/// Never renders "Time unknown"/"TBC"/any placeholder — absence of a time
/// already communicates "date only" on its own; inventing a label for
/// that absence would read as a data-quality complaint aimed at the
/// viewer, not a calm editorial choice.
String formatEventDateAndTime(Event event) {
  final dateRange = formatEventDateRange(event);
  final startTime = event.startTime;
  final endTime = event.endTime;
  if (startTime == null) return dateRange;
  if (endTime == null) return '$dateRange · ${startTime.format()}';
  return '$dateRange · ${startTime.format()}–${endTime.format()}';
}
