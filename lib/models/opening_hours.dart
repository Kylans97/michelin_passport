/// A time of day, to the minute, as the venue gives it. No timezone: the
/// page shows a restaurant's hours as the restaurant states them, never
/// converted to the viewer's clock.
class HoursTime implements Comparable<HoursTime> {
  final int hour;
  final int minute;

  const HoursTime(this.hour, this.minute);

  /// "HH:MM" or "HH:MM:SS", as Postgres `time` comes back.
  factory HoursTime.parse(String value) {
    final parts = value.split(':');
    return HoursTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  int get minutes => hour * 60 + minute;

  /// "12:00".
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(HoursTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is HoursTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// One opening on one day. A range that closes before it opens runs past
/// midnight (18:00–01:00).
class HoursRange {
  final HoursTime opens;
  final HoursTime closes;

  const HoursRange(this.opens, this.closes);

  bool get pastMidnight => closes.minutes < opens.minutes;

  String get label => '${opens.label}–${closes.label}';

  @override
  bool operator ==(Object other) =>
      other is HoursRange && other.opens == opens && other.closes == closes;

  @override
  int get hashCode => Object.hash(opens, closes);
}

/// A restaurant's week (restaurant_opening_hours, 20261101180000): per
/// ISO weekday (1 = Monday) none, one or two ranges. A day without ranges
/// is closed; a week with no ranges at all means the restaurant gave no
/// hours, and the page shows nothing.
class OpeningHours {
  /// Weekday -> ranges in opening order. Days without ranges are absent.
  final Map<int, List<HoursRange>> days;

  const OpeningHours(this.days);

  static const empty = OpeningHours({});

  bool get isEmpty => days.values.every((r) => r.isEmpty);

  List<HoursRange> on(int weekday) => days[weekday] ?? const [];

  factory OpeningHours.fromRows(Iterable<Map<String, dynamic>> rows) {
    final days = <int, List<HoursRange>>{};
    final sorted = [...rows]
      ..sort((a, b) {
        final byDay = (a['weekday'] as int).compareTo(b['weekday'] as int);
        return byDay != 0
            ? byDay
            : (a['slot'] as int).compareTo(b['slot'] as int);
      });
    for (final row in sorted) {
      (days[row['weekday'] as int] ??= []).add(
        HoursRange(
          HoursTime.parse(row['opens_at'] as String),
          HoursTime.parse(row['closes_at'] as String),
        ),
      );
    }
    return OpeningHours(days);
  }

  /// What set_restaurant_opening_hours takes.
  List<Map<String, dynamic>> toRpcJson() => [
    for (final entry in days.entries)
      for (final range in entry.value)
        {
          'weekday': entry.key,
          'opens': range.opens.label,
          'closes': range.closes.label,
        },
  ];

  /// Why this week can't be saved, or null when it can — the same rules
  /// the database enforces, checked first so the editor can say which
  /// day is wrong.
  String? validationError() {
    for (final day in days.keys) {
      final ranges = [...on(day)]..sort((a, b) => a.opens.compareTo(b.opens));
      if (ranges.length > 2) {
        return '${weekdayName(day)}: at most two times a day.';
      }
      for (final r in ranges) {
        if (r.opens == r.closes) {
          return '${weekdayName(day)}: opening and closing times must differ.';
        }
      }
      if (ranges.length == 2) {
        if (ranges.first.pastMidnight) {
          return '${weekdayName(day)}: only the last time of the day can run past midnight.';
        }
        if (ranges[1].opens.minutes < ranges.first.closes.minutes) {
          return '${weekdayName(day)}: the two times overlap.';
        }
      }
    }
    return null;
  }

  /// The page's lines: consecutive days with the same hours folded into
  /// one ("Tue – Sat"), closed days included so the week reads whole.
  List<OpeningHoursLine> get lines {
    final lines = <OpeningHoursLine>[];
    var start = 1;
    while (start <= 7) {
      var end = start;
      while (end < 7 && _sameRanges(on(end + 1), on(start))) {
        end++;
      }
      lines.add(OpeningHoursLine(start, end, on(start)));
      start = end + 1;
    }
    return lines;
  }

  static bool _sameRanges(List<HoursRange> a, List<HoursRange> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// What "Add a second time" proposes after [first]: dinner after lunch
/// (four hours after it closes, until 22:00), or — when that no longer
/// fits in the day — a late range of two hours starting an hour after it,
/// past midnight if need be. Never an empty range.
HoursRange suggestSecondRange(HoursRange first) {
  final opens = first.closes.minutes + 240;
  if (opens + 60 <= 22 * 60) {
    return HoursRange(
      HoursTime(opens ~/ 60, opens % 60),
      const HoursTime(22, 0),
    );
  }
  final start = (first.closes.minutes + 60) % (24 * 60);
  final end = (start + 120) % (24 * 60);
  return HoursRange(
    HoursTime(start ~/ 60, start % 60),
    HoursTime(end ~/ 60, end % 60),
  );
}

class OpeningHoursLine {
  final int firstDay;
  final int lastDay;
  final List<HoursRange> ranges;

  const OpeningHoursLine(this.firstDay, this.lastDay, this.ranges);

  /// "Mon", "Tue – Sat".
  String get daysLabel => firstDay == lastDay
      ? weekdayShortName(firstDay)
      : '${weekdayShortName(firstDay)} – ${weekdayShortName(lastDay)}';

  /// "12:00–14:00 · 19:00–22:00", or "Closed".
  String get hoursLabel =>
      ranges.isEmpty ? 'Closed' : ranges.map((r) => r.label).join(' · ');
}

const _names = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayName(int weekday) => _names[weekday - 1];

String weekdayShortName(int weekday) => _names[weekday - 1].substring(0, 3);
