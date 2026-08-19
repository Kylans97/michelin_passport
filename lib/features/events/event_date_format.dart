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
String formatEventDateRange(Event event) {
  final s = eventLocalDateTime(event.startAt, event.timezone);
  final e = eventLocalDateTime(event.endAt, event.timezone);
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
