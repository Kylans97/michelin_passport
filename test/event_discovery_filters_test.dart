// Events V2 Discovery Taxonomy Phase B — the domain model itself
// (lib/models/event_discovery_filters.dart): normalization, immutability,
// value equality, isEmpty/activeDimensionCount, and date-preset
// resolution. No Supabase dependency anywhere in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';

void main() {
  group('EventDiscoveryFilters — normalization', () {
    test('tag slugs are lowercased and trimmed', () {
      final filters = EventDiscoveryFilters(tagSlugs: {' Wine ', 'WILD_game'});
      expect(filters.tagSlugs, {'wine', 'wild_game'});
    });

    test('country codes are uppercased and trimmed', () {
      final filters = EventDiscoveryFilters(countryCodes: {' nl ', 'dk'});
      expect(filters.countryCodes, {'NL', 'DK'});
    });

    test('duplicate values collapse (Set semantics)', () {
      final filters = EventDiscoveryFilters(
        tagSlugs: {'wine', 'WINE', ' wine '},
      );
      expect(filters.tagSlugs, {'wine'});
    });

    test('fields are unmodifiable', () {
      final filters = EventDiscoveryFilters(eventTypes: {EventType.dinner});
      expect(
        () => filters.eventTypes.add(EventType.lunch),
        throwsUnsupportedError,
      );
    });
  });

  group('EventDiscoveryFilters — isEmpty / activeDimensionCount', () {
    test('default filters are empty with zero active dimensions', () {
      final filters = EventDiscoveryFilters();
      expect(filters.isEmpty, isTrue);
      expect(filters.activeDimensionCount, 0);
    });

    test('one non-empty dimension counts as exactly 1, regardless of how '
        'many values are selected within it', () {
      final filters = EventDiscoveryFilters(
        tagSlugs: {'wine', 'guest_chef', 'four_hands'},
      );
      expect(filters.isEmpty, isFalse);
      expect(filters.activeDimensionCount, 1);
    });

    test('every dimension active counts all five', () {
      final filters = EventDiscoveryFilters(
        social: {EventSocialFilter.friendsGoing},
        eventTypes: {EventType.dinner},
        tagSlugs: {'wine'},
        countryCodes: {'NL'},
        dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 1)),
      );
      expect(filters.activeDimensionCount, 5);
    });
  });

  group('EventDiscoveryFilters — advancedFilterDimensionCount '
      '(Phase C Correction Pass §11)', () {
    test('default filters count zero', () {
      expect(EventDiscoveryFilters().advancedFilterDimensionCount, 0);
    });

    test('Location (countryCodes) and Date never contribute, even when '
        'active', () {
      final filters = EventDiscoveryFilters(
        countryCodes: {'NL'},
        dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 1)),
      );
      expect(filters.advancedFilterDimensionCount, 0);
      // activeDimensionCount (the original, unrepurposed getter) still
      // correctly counts both — proving this is a new, narrower count,
      // not a behavior change to the existing one.
      expect(filters.activeDimensionCount, 2);
    });

    test('Social, Type and Theme each contribute exactly 1', () {
      final filters = EventDiscoveryFilters(
        social: {EventSocialFilter.friendsGoing},
        eventTypes: {EventType.dinner},
        tagSlugs: {'wine'},
      );
      expect(filters.advancedFilterDimensionCount, 3);
    });

    test('Location + Date + all three advanced dimensions active at '
        'once still reports exactly 3 (never 5)', () {
      final filters = EventDiscoveryFilters(
        social: {EventSocialFilter.friendsGoing},
        eventTypes: {EventType.dinner},
        tagSlugs: {'wine'},
        countryCodes: {'NL'},
        dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 1)),
      );
      expect(filters.advancedFilterDimensionCount, 3);
      expect(filters.activeDimensionCount, 5);
    });
  });

  group('EventDiscoveryFilters — equality', () {
    test('two filters with the same values (different construction order) '
        'are equal', () {
      final a = EventDiscoveryFilters(
        tagSlugs: {'wine', 'guest_chef'},
        countryCodes: {'NL', 'BE'},
      );
      final b = EventDiscoveryFilters(
        tagSlugs: {'guest_chef', 'wine'},
        countryCodes: {'BE', 'NL'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing dateRange breaks equality', () {
      final a = EventDiscoveryFilters(
        dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 1)),
      );
      final b = EventDiscoveryFilters(
        dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 2)),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('EventDiscoveryFilters — copyWith', () {
    test('copyWith replaces only the given field', () {
      final base = EventDiscoveryFilters(eventTypes: {EventType.dinner});
      final updated = base.copyWith(tagSlugs: {'wine'});
      expect(updated.eventTypes, {EventType.dinner});
      expect(updated.tagSlugs, {'wine'});
    });
  });

  group('EventDiscoveryFilters — selectableEventTypes', () {
    test('contains exactly the seven V1 types, excluding legacy values', () {
      expect(EventDiscoveryFilters.selectableEventTypes, {
        EventType.dinner,
        EventType.lunch,
        EventType.festival,
        EventType.gala,
        EventType.tasting,
        EventType.brunch,
        EventType.party,
      });
      expect(
        EventDiscoveryFilters.selectableEventTypes,
        isNot(contains(EventType.experience)),
      );
      expect(
        EventDiscoveryFilters.selectableEventTypes,
        isNot(contains(EventType.market)),
      );
      expect(
        EventDiscoveryFilters.selectableEventTypes,
        isNot(contains(EventType.other)),
      );
    });
  });

  group('EventDiscoveryDateRange — normalization', () {
    test('from before to stays unchanged', () {
      final range = EventDiscoveryDateRange.normalized(
        from: DateTime.utc(2026, 9, 1),
        to: DateTime.utc(2026, 9, 10),
      );
      expect(range.from, DateTime.utc(2026, 9, 1));
      expect(range.to, DateTime.utc(2026, 9, 10));
    });

    test('an inverted range (from after to) is swapped, not dropped', () {
      final range = EventDiscoveryDateRange.normalized(
        from: DateTime.utc(2026, 9, 10),
        to: DateTime.utc(2026, 9, 1),
      );
      expect(range.from, DateTime.utc(2026, 9, 1));
      expect(range.to, DateTime.utc(2026, 9, 10));
    });

    test('an open range (either side null) is left alone, not treated as '
        'inverted', () {
      final range = EventDiscoveryDateRange.normalized(
        from: DateTime.utc(2026, 9, 1),
      );
      expect(range.from, DateTime.utc(2026, 9, 1));
      expect(range.to, isNull);
    });
  });

  group('resolveEventDiscoveryDateRange — presets', () {
    final wednesday = DateTime.utc(2026, 9, 16); // a Wednesday

    test('none resolves to an empty range', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.none,
        now: wednesday,
      );
      expect(range.isEmpty, isTrue);
    });

    test('today resolves to a single-day range', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.today,
        now: wednesday,
      );
      expect(range.from, DateTime.utc(2026, 9, 16));
      expect(range.to, DateTime.utc(2026, 9, 16));
    });

    test('thisWeekend resolves to the upcoming Saturday-Sunday from a '
        'weekday', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.thisWeekend,
        now: wednesday,
      );
      expect(range.from, DateTime.utc(2026, 9, 19)); // Saturday
      expect(range.to, DateTime.utc(2026, 9, 20)); // Sunday
    });

    test('thisWeekend resolves to the CURRENT weekend when already '
        'Saturday', () {
      final saturday = DateTime.utc(2026, 9, 19);
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.thisWeekend,
        now: saturday,
      );
      expect(range.from, DateTime.utc(2026, 9, 19));
      expect(range.to, DateTime.utc(2026, 9, 20));
    });

    test('thisWeekend resolves to the CURRENT weekend when already '
        'Sunday', () {
      final sunday = DateTime.utc(2026, 9, 20);
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.thisWeekend,
        now: sunday,
      );
      expect(range.from, DateTime.utc(2026, 9, 19));
      expect(range.to, DateTime.utc(2026, 9, 20));
    });

    test('thisMonth resolves to the full calendar month', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.thisMonth,
        now: wednesday,
      );
      expect(range.from, DateTime.utc(2026, 9, 1));
      expect(range.to, DateTime.utc(2026, 9, 30));
    });

    test('thisMonth correctly resolves December (year rollover)', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.thisMonth,
        now: DateTime.utc(2026, 12, 10),
      );
      expect(range.from, DateTime.utc(2026, 12, 1));
      expect(range.to, DateTime.utc(2026, 12, 31));
    });

    test('custom returns the supplied range verbatim', () {
      final custom = EventDiscoveryDateRange(
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 5),
      );
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.custom,
        now: wednesday,
        customRange: custom,
      );
      expect(range, custom);
    });

    test('custom with no supplied range falls back to empty rather than '
        'throwing', () {
      final range = resolveEventDiscoveryDateRange(
        EventDiscoveryDatePreset.custom,
        now: wednesday,
      );
      expect(range.isEmpty, isTrue);
    });
  });
}
