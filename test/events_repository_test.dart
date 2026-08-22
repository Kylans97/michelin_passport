// Events V2 Time Precision Phase C — EventsRepository.loadEvents' query
// migration off start_at/end_at (nullable from Phase C onward) onto
// start_date/end_date. EventsRepository itself constructs SupabaseClient
// at field-init time, unavailable in this sandbox without
// Supabase.initialize() (the same, already-documented limitation as
// event_confirmed_attendance_repository_test.dart) — so the exact SQL
// filter/order arithmetic is extracted into the standalone
// eventBrowseWindowBounds function and tested here as a pure function;
// the network call itself, and that a date-only row is genuinely
// returned by an equivalent WHERE clause, is proven separately against
// local Postgres — see
// docs/Architecture/Events/EVENT_TIME_PRECISION_PHASE_C_PRE_APPLY.md's
// Local Date-Only Insert section.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/events_repository.dart';

void main() {
  group('eventBrowseWindowBounds — conservative one-day widening', () {
    test('from and to both null: no bounds at all (unbounded browse, e.g. '
        "Explore's country-picker-only / free-text-only search)", () {
      final bounds = eventBrowseWindowBounds(from: null, to: null);
      expect(bounds.gteEndDate, isNull);
      expect(bounds.lteStartDate, isNull);
    });

    test('from only (EventDateFilterMode.upcoming): gteEndDate is one day '
        'before from, lteStartDate stays null (no upper bound)', () {
      final bounds = eventBrowseWindowBounds(
        from: DateTime(2026, 9, 10),
        to: null,
      );
      expect(bounds.gteEndDate, '2026-09-09');
      expect(bounds.lteStartDate, isNull);
    });

    test('from and to both set (thisWeek/month/custom): widened by one day '
        'on each open end', () {
      final bounds = eventBrowseWindowBounds(
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 17),
      );
      expect(bounds.gteEndDate, '2026-09-09');
      expect(bounds.lteStartDate, '2026-09-18');
    });

    test('widening correctly crosses a month boundary', () {
      final bounds = eventBrowseWindowBounds(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 8, 31),
      );
      expect(bounds.gteEndDate, '2026-08-31');
      expect(bounds.lteStartDate, '2026-09-01');
    });

    test('widening correctly crosses a year boundary', () {
      final bounds = eventBrowseWindowBounds(
        from: DateTime(2027, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(bounds.gteEndDate, '2026-12-31');
      expect(bounds.lteStartDate, '2027-01-01');
    });

    test('the time-of-day component of from/to is irrelevant — only the '
        'calendar date is ever used (a device-local DateTime carrying a '
        'non-midnight time must not shift which day gets widened)', () {
      final bounds = eventBrowseWindowBounds(
        from: DateTime(2026, 9, 10, 23, 59, 59),
        to: DateTime(2026, 9, 10, 0, 0, 1),
      );
      expect(bounds.gteEndDate, '2026-09-09');
      expect(bounds.lteStartDate, '2026-09-11');
    });
  });
}
