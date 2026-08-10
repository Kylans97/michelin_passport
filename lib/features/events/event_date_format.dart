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
/// multi-day event, "27 Aug 2026" for a single-day one.
String formatEventDateRange(Event event) {
  final s = event.startAt;
  final e = event.endAt;
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

/// Full date + time for Event Detail — "Thu 27 Aug 2026, 18:00".
String formatEventDateTime(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = weekdays[date.weekday - 1];
  return '$weekday ${date.day} ${_monthNames[date.month - 1]} ${date.year}, '
      '${_pad2(date.hour)}:${_pad2(date.minute)}';
}
