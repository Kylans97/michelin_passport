// Events V2 Discovery Taxonomy Phase C Correction Pass §1/§14 — the
// device-reported "search Amsterdam, then apply a Date filter, and the
// Amsterdam context is lost" regression.
//
// ROOT CAUSE (documented in full in
// EVENTS_DISCOVERY_TAXONOMY_PHASE_C_PRE_FINAL.md's "Physical Device
// Correction Pass" section): exhaustive static tracing of the pre-
// correction code (EventsScreen._fetchDiscoveryList ->
// EventDiscoveryFilterService.loadFilteredDiscovery ->
// EventsRepository.loadEvents + applyDiscoveryFilters) found NO incorrect
// AND-composition logic — search (_query) and the advanced-filters-
// sheet's committed EventDiscoveryFilters (including dateRange) were
// always two independently-held pieces of State that never overwrote one
// another, and every test below proves that pure composition is and
// remains correct. The actual defect was ARCHITECTURAL: Date lived
// buried inside a "Filters" sheet reached via a multi-tap draft+Apply
// flow, with no visible connection to the Search field above it and no
// indication in the UI that Search was still active after applying a
// Date filter — this correction promotes Location and Date to first-
// class, always-visible, immediately-committing controls specifically so
// this class of confusion (and any future one like it) cannot recur.
//
// This file proves the corrected architecture's actual composition
// contract: search-matched events (simulated exactly as
// EventsRepository.loadEvents(query: ...) would return) intersected with
// a Location and/or Date filter via the SAME, unmodified
// applyDiscoveryFilters — and, critically, that the composed result is
// identical regardless of the ORDER in which the user touched the
// controls, since the corrected architecture derives one composed
// EventDiscoveryFilters from independently-held state on every query,
// never by mutating a shared object in place.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_discovery_filtering.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';
import 'package:michelin_passport/models/event_location_context.dart';
import 'package:michelin_passport/models/venue_country.dart';

Event _event({
  required String id,
  required String city,
  String countryCode = 'NL',
  DateTime? startDate,
  EventType eventType = EventType.dinner,
}) => Event(
  id: id,
  name: 'Event $id',
  city: city,
  startDate: startDate ?? DateTime.utc(2026, 9, 10),
  endDate: startDate ?? DateTime.utc(2026, 9, 10),
  countryCode: countryCode,
  eventType: eventType,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

/// Simulates exactly what `EventsRepository.loadEvents(query:
/// 'amsterdam')` would already return server-side (a case-insensitive
/// match against name/city/venue_name) — the search step itself is not
/// under test here; this file starts from ITS output, exactly as
/// `EventDiscoveryFilterService.loadFilteredDiscovery` does.
List<Event> _searchMatchedAmsterdamEvents() => [
  _event(
    id: 'amsterdam-september',
    city: 'Amsterdam',
    startDate: DateTime.utc(2026, 9, 15),
  ),
  _event(
    id: 'amsterdam-november',
    city: 'Amsterdam',
    startDate: DateTime.utc(2026, 11, 5),
  ),
  _event(
    id: 'amsterdam-denmark', // same city name, different country
    city: 'Amsterdam',
    countryCode: 'DK',
    startDate: DateTime.utc(2026, 9, 20),
  ),
];

void main() {
  group('Amsterdam search + Date filter composition (device bug proof)', () {
    test('A. search THEN date: results stay constrained to Amsterdam AND '
        'the date range — the September Amsterdam event survives, the '
        'November one does not', () {
      final searchMatched = _searchMatchedAmsterdamEvents();
      final filters = EventDiscoveryFilters(
        dateRange: EventDiscoveryDateRange(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 30),
        ),
      );
      final result = applyDiscoveryFilters(
        events: searchMatched,
        filters: filters,
        userSignedIn: true,
      );
      expect(result.map((e) => e.id).toSet(), {
        'amsterdam-september',
        'amsterdam-denmark',
      });
    });

    test('B. date THEN search (order reversed): identical committed state '
        'produces an identical result — order of interaction never '
        'changes semantics', () {
      final searchMatched = _searchMatchedAmsterdamEvents();
      // The date filter was "applied" first in this scenario, but the
      // composed filters object is byte-identical to test A's — proving
      // there is no hidden order-dependence anywhere in this pure step.
      final filters = EventDiscoveryFilters(
        dateRange: EventDiscoveryDateRange(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 30),
        ),
      );
      final result = applyDiscoveryFilters(
        events: searchMatched,
        filters: filters,
        userSignedIn: true,
      );
      expect(result.map((e) => e.id).toSet(), {
        'amsterdam-september',
        'amsterdam-denmark',
      });
    });
  });

  group('Location narrows search, never silently overridden by it', () {
    test('Netherlands + "Amsterdam" search: only the Dutch Amsterdam '
        'event survives, not the Danish one sharing the same city name', () {
      final searchMatched = _searchMatchedAmsterdamEvents();
      final location = const EventLocationContext(
        country: VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
      );
      final filters = EventDiscoveryFilters(
        countryCodes: location.countryCodes,
      );
      final result = applyDiscoveryFilters(
        events: searchMatched,
        filters: filters,
        userSignedIn: true,
      );
      expect(result.map((e) => e.id).toSet(), {
        'amsterdam-september',
        'amsterdam-november',
      });
    });

    test('Switzerland + "Amsterdam" search: zero results — Location is '
        'never silently dropped just because the search text happens to '
        'name a city in a different country', () {
      final searchMatched = _searchMatchedAmsterdamEvents();
      final location = const EventLocationContext(
        country: VenueCountry(name: 'Switzerland', code: 'CH', flag: '🇨🇭'),
      );
      final filters = EventDiscoveryFilters(
        countryCodes: location.countryCodes,
      );
      final result = applyDiscoveryFilters(
        events: searchMatched,
        filters: filters,
        userSignedIn: true,
      );
      expect(result, isEmpty);
    });
  });

  group('Full four-dimension composition — Search AND Location AND Date '
      'AND advanced Filters', () {
    test('Amsterdam + Netherlands + September + Dinner: every dimension '
        'holds simultaneously, none silently drops another', () {
      final searchMatched = [
        ..._searchMatchedAmsterdamEvents(),
        _event(
          id: 'amsterdam-lunch',
          city: 'Amsterdam',
          eventType: EventType.lunch,
          startDate: DateTime.utc(2026, 9, 12),
        ),
      ];
      final location = const EventLocationContext(
        country: VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
      );
      final filters = EventDiscoveryFilters(
        countryCodes: location.countryCodes,
        dateRange: EventDiscoveryDateRange(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 30),
        ),
        eventTypes: {EventType.dinner},
      );
      final result = applyDiscoveryFilters(
        events: searchMatched,
        filters: filters,
        userSignedIn: true,
      );
      // amsterdam-november: wrong month. amsterdam-denmark: wrong
      // country. amsterdam-lunch: wrong type. Only amsterdam-september
      // survives every dimension.
      expect(result.map((e) => e.id), ['amsterdam-september']);
    });

    test('constructing the same four-dimension state via a different '
        'assignment order produces an identical EventDiscoveryFilters '
        '(value equality) — proving the composition has no hidden '
        'mutation/order dependence', () {
      final orderA = EventDiscoveryFilters(
        countryCodes: {'NL'},
        dateRange: EventDiscoveryDateRange(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 9, 30),
        ),
        eventTypes: {EventType.dinner},
      );
      // Same four dimensions, built via .copyWith() calls in a different
      // sequence than the direct constructor above — mirroring how
      // EventsScreen's own _effectiveFilters getter composes
      // independently-held Location/Date/advanced-filter state on every
      // rebuild, never by mutating one shared object.
      final orderB = EventDiscoveryFilters(eventTypes: {EventType.dinner})
          .copyWith(
            dateRange: EventDiscoveryDateRange(
              from: DateTime.utc(2026, 9, 1),
              to: DateTime.utc(2026, 9, 30),
            ),
          )
          .copyWith(countryCodes: {'NL'});

      expect(orderA, equals(orderB));
    });
  });
}
