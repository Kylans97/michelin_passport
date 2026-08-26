// PROFILE UI REDESIGN V1 — pure-function coverage for
// lib/features/profile/journey_metrics.dart's computeJourneyMetrics, the
// exact, audited definition of Profile's compact "Your Journey" card
// (Places/Countries only — Events/Trips were folded into Places or
// removed entirely, see the "Your Journey" card refinement). Entirely
// pure (no Supabase, no widgets) — every fixture below is built by hand
// so each rule is exercised in isolation, matching this codebase's
// established "test the pure part directly and completely" convention
// (see passport_event_attendance_domain_test.dart's own note).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/features/profile/journey_metrics.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  String countryCode = 'FR',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: 'Paris',
  countryCode: countryCode,
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  String countryCode = 'FR',
}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: 1,
  cityName: 'Paris',
  countryCode: countryCode,
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _visit({
  String id = 'v1',
  String entityType = 'restaurant',
  String entityId = 'r1',
  DateTime? visitedOn,
}) => Visit(
  id: id,
  userId: 'u1',
  entityType: entityType,
  entityId: entityId,
  visitedOn: visitedOn ?? DateTime(2026, 1, 1),
);

Event _event({
  required String id,
  String countryCode = 'NL',
  DateTime? startDate,
}) => Event(
  id: id,
  name: 'Test Event',
  startDate: startDate ?? DateTime.utc(2026, 3, 1),
  endDate: startDate ?? DateTime.utc(2026, 3, 1),
  timezone: 'Europe/Amsterdam',
  countryCode: countryCode,
  eventType: EventType.dinner,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

EventConfirmedAttendance _attendance({required String id, required String eventId}) =>
    EventConfirmedAttendance(
      id: id,
      eventId: eventId,
      userId: 'u1',
      confirmedAt: DateTime.utc(2026, 1, 1),
      visibility: ConfirmedAttendanceVisibility.private,
      source: EventAttendanceSource.manual,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('places — aggregate of restaurants + hotels + confirmed events', () {
    test('counts unique venues, one per venue regardless of visit count', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [
          VenueEntry(
            venue: RestaurantVenue(_restaurant(id: 'r1')),
            visits: [
              _visit(id: 'v1', visitedOn: DateTime(2026, 1, 1)),
              _visit(id: 'v2', visitedOn: DateTime(2026, 2, 1)),
              _visit(id: 'v3', visitedOn: DateTime(2026, 3, 1)),
            ],
          ),
        ],
        confirmedEventAttendance: [],
      );
      expect(metrics.places, 1);
    });

    test('a restaurant, a hotel, and a confirmed event all add to the same '
        'Places total', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [
          VenueEntry(
            venue: RestaurantVenue(_restaurant(id: 'r1')),
            visits: [_visit(id: 'v1')],
          ),
          VenueEntry(
            venue: HotelVenue(_hotel(id: 'h1')),
            visits: [_visit(id: 'v2', entityType: 'hotel', entityId: 'h1')],
          ),
        ],
        confirmedEventAttendance: [
          EventAttendanceEntry(
            attendance: _attendance(id: 'a1', eventId: 'e1'),
            event: _event(id: 'e1'),
          ),
        ],
      );
      // 1 restaurant + 1 hotel + 1 event = 3.
      expect(metrics.places, 3);
    });

    test('confirmed events alone (no venues) still count', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [],
        confirmedEventAttendance: [
          EventAttendanceEntry(
            attendance: _attendance(id: 'a1', eventId: 'e1'),
            event: _event(id: 'e1'),
          ),
          EventAttendanceEntry(
            attendance: _attendance(id: 'a2', eventId: 'e2'),
            event: _event(id: 'e2'),
          ),
        ],
      );
      expect(metrics.places, 2);
    });

    test('empty when nothing visited or attended', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [],
        confirmedEventAttendance: [],
      );
      expect(metrics.places, 0);
    });
  });

  group('countries', () {
    test('a restaurant and a hotel in the same country count once', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [
          VenueEntry(
            venue: RestaurantVenue(_restaurant(id: 'r1', countryCode: 'FR')),
            visits: [_visit()],
          ),
          VenueEntry(
            venue: HotelVenue(_hotel(id: 'h1', countryCode: 'FR')),
            visits: [_visit(entityType: 'hotel', entityId: 'h1')],
          ),
        ],
        confirmedEventAttendance: [],
      );
      expect(metrics.countries, 1);
    });

    test('unions country sources across visited venues AND '
        'confirmed-attendance events — never Wishlist, never Trips, never '
        'Interested-only events (those never reach this function)', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [
          VenueEntry(
            venue: RestaurantVenue(_restaurant(id: 'r1', countryCode: 'FR')),
            visits: [_visit()],
          ),
        ],
        confirmedEventAttendance: [
          EventAttendanceEntry(
            attendance: _attendance(id: 'a1', eventId: 'e1'),
            event: _event(id: 'e1', countryCode: 'NL'),
          ),
        ],
      );
      expect(metrics.countries, 2);
    });

    test('empty country codes are excluded, never counted as a real '
        'country — no code on file is never guessed at', () {
      final metrics = computeJourneyMetrics(
        passportVenues: [
          VenueEntry(
            venue: RestaurantVenue(_restaurant(id: 'r1', countryCode: '')),
            visits: [_visit()],
          ),
        ],
        confirmedEventAttendance: [
          EventAttendanceEntry(
            attendance: _attendance(id: 'a1', eventId: 'e1'),
            event: _event(id: 'e1', countryCode: ''),
          ),
        ],
      );
      expect(metrics.countries, 0);
      // Places still counts both experiences — a missing country code
      // excludes something from the Countries count only, never from
      // Places itself.
      expect(metrics.places, 2);
    });
  });

  test('a fully empty journey reports all zeros, never a crash', () {
    final metrics = computeJourneyMetrics(
      passportVenues: [],
      confirmedEventAttendance: [],
    );
    expect(metrics.places, 0);
    expect(metrics.countries, 0);
  });
}
