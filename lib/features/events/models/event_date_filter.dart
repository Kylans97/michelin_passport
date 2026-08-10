import 'package:flutter/material.dart' show DateTimeRange;

/// The four date-filter modes Events discovery supports. Deliberately
/// small and screen-scoped (not a design-system concept) since nothing
/// else in the app filters by date range yet.
enum EventDateFilterMode { upcoming, thisWeek, month, custom }

/// Resolves an [EventDateFilterMode] into the concrete [from, to] window
/// EventsRepository.loadEvents() filters on. [monthAnchor]/[customRange]
/// only matter for their respective modes. Uses Flutter's own
/// [DateTimeRange] (the type showDateRangePicker already returns) rather
/// than inventing a parallel one.
class EventDateFilter {
  final EventDateFilterMode mode;
  final DateTime monthAnchor;
  final DateTimeRange? customRange;

  EventDateFilter({required this.mode, DateTime? monthAnchor, this.customRange})
    : monthAnchor = monthAnchor ?? DateTime.now();

  (DateTime? from, DateTime? to) resolve() {
    final now = DateTime.now();
    switch (mode) {
      case EventDateFilterMode.upcoming:
        return (DateTime(now.year, now.month, now.day), null);
      case EventDateFilterMode.thisWeek:
        final weekday = now.weekday; // 1 = Monday
        final monday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        final sundayEndExclusive = monday.add(const Duration(days: 7));
        return (monday, sundayEndExclusive);
      case EventDateFilterMode.month:
        final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
        final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
        return (start, end);
      case EventDateFilterMode.custom:
        if (customRange == null) return (null, null);
        return (
          customRange!.start,
          customRange!.end.add(const Duration(days: 1)),
        );
    }
  }

  EventDateFilter copyWith({
    EventDateFilterMode? mode,
    DateTime? monthAnchor,
    DateTimeRange? customRange,
  }) => EventDateFilter(
    mode: mode ?? this.mode,
    monthAnchor: monthAnchor ?? this.monthAnchor,
    customRange: customRange ?? this.customRange,
  );
}
