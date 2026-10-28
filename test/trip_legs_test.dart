// Multi-destination trips (20261022120000): leg helpers, per-leg event
// matching (decision 2), and the new trip/notification models. Pure — no
// Supabase.
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/trips/trip_legs.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_trip_match.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/planned_venue.dart';
import 'package:michelin_passport/models/resolved_planned_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/trip_destination.dart';
import 'package:michelin_passport/models/trip_member.dart';

const _paris = 'city-paris';

final _paris1to5 = TripDestination(
  countryCode: 'FR',
  cityId: _paris,
  cityName: 'Paris',
  startDate: DateTime(2026, 12, 1),
  endDate: DateTime(2026, 12, 5),
);
final _italy5to10 = TripDestination(
  countryCode: 'IT',
  startDate: DateTime(2026, 12, 5),
  endDate: DateTime(2026, 12, 10),
);

PlannedTrip _trip({List<TripDestination> legs = const [], String? city}) =>
    PlannedTrip(
      id: 't1',
      userId: 'u1',
      title: 'Paris and Italy',
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2026, 12, 10),
      countryCode: 'FR',
      city: city,
      createdAt: DateTime(2026, 1, 1),
      destinations: legs,
    );

Restaurant _restaurant(String country, String? cityId) => Restaurant(
  id: 'r-$country-$cityId',
  restaurantCode: 'r',
  name: 'R',
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: 'X',
  countryCode: country,
  cityId: cityId,
  countryName: 'X',
  flagEmoji: '',
  address: 'a',
  isInHotel: false,
  hotelName: null,
  worlds50BestRank: null,
);

Hotel _hotel(String country, String? cityId) => Hotel(
  id: 'h-$country-$cityId',
  hotelCode: 'h',
  name: 'H',
  michelinKeys: 1,
  cityName: 'X',
  countryCode: country,
  cityId: cityId,
  countryName: 'X',
  flagEmoji: '',
  address: 'a',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: null,
);

ResolvedPlannedVenue _plan(PassportVenue venue, DateTime start) =>
    ResolvedPlannedVenue(
      plan: PlannedVenue(
        id: 'p',
        userId: 'u1',
        entityType: venue is HotelVenue ? 'hotel' : 'restaurant',
        entityId: 'e',
        tripId: 't1',
        startDate: start,
        status: PlannedVenueStatus.planned,
        createdAt: DateTime(2026, 1, 1),
      ),
      venue: venue,
    );

Event _event({
  required String country,
  required DateTime start,
  required DateTime end,
  String? city,
}) => Event.fromJson({
  'id': 'e-$country-${start.day}',
  'name': 'Dinner',
  'description': null,
  'start_at': start.toUtc().toIso8601String(),
  'end_at': end.toUtc().toIso8601String(),
  'start_date':
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
  'end_date':
      '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
  'country_code': country,
  'city': city,
  'venue_name': null,
  'address': null,
  'latitude': null,
  'longitude': null,
  'official_url': null,
  'ticket_url': null,
  'image_url': null,
  'event_type': 'dinner',
  'status': 'upcoming',
  'created_at': '2026-01-01T00:00:00+00:00',
});

void main() {
  group('effectiveLegs', () {
    test('a trip without loaded destinations has one, its own country', () {
      final legs = effectiveLegs(_trip());
      expect(legs, hasLength(1));
      expect(legs.single.countryCode, 'FR');
      expect(legs.single.cityId, isNull);
    });

    test('loaded destinations are used as they are', () {
      expect(effectiveLegs(_trip(legs: [_paris1to5, _italy5to10])), [
        _paris1to5,
        _italy5to10,
      ]);
    });
  });

  group('legScope (picker scope — codes and ids only)', () {
    test('city legs give city ids, whole-country legs give country codes', () {
      final scope = legScope([_paris1to5, _italy5to10]);
      expect(scope.cityIds, [_paris]);
      expect(scope.countryCodes, ['IT']);
    });
  });

  group('legIndexForPlan', () {
    final trip = _trip(legs: [_paris1to5, _italy5to10]);

    test('a Paris restaurant on 3 Dec is in the Paris leg', () {
      final item = _plan(
        RestaurantVenue(_restaurant('FR', _paris)),
        DateTime(2026, 12, 3),
      );
      expect(legIndexForPlan(trip, item), 0);
    });

    test('an Italian hotel on 6 Dec is in the Italy leg', () {
      final item = _plan(
        HotelVenue(_hotel('IT', 'city-rome')),
        DateTime(2026, 12, 6),
      );
      expect(legIndexForPlan(trip, item), 1);
    });

    test('a French restaurant outside Paris belongs to no leg', () {
      final item = _plan(
        RestaurantVenue(_restaurant('FR', 'city-lyon')),
        DateTime(2026, 12, 3),
      );
      expect(legIndexForPlan(trip, item), isNull);
    });

    test('matches by place when the date falls outside every leg', () {
      final item = _plan(
        RestaurantVenue(_restaurant('IT', 'city-rome')),
        DateTime(2026, 12, 2),
      );
      expect(legIndexForPlan(trip, item), 1);
    });

    test('Paris twice: the date picks the right leg', () {
      final back = TripDestination(
        countryCode: 'FR',
        cityId: _paris,
        cityName: 'Paris',
        startDate: DateTime(2026, 12, 9),
        endDate: DateTime(2026, 12, 10),
      );
      final twice = _trip(legs: [_paris1to5, _italy5to10, back]);
      final item = _plan(
        RestaurantVenue(_restaurant('FR', _paris)),
        DateTime(2026, 12, 10),
      );
      expect(legIndexForPlan(twice, item), 2);
    });
  });

  group('per-leg event matching (decision 2)', () {
    final trip = _trip(legs: [_paris1to5, _italy5to10]);

    test('an Italian event during the Italian dates matches', () {
      final event = _event(
        country: 'IT',
        start: DateTime(2026, 12, 7, 19),
        end: DateTime(2026, 12, 7, 23),
      );
      expect(eventMatchesTrip(event, trip), isTrue);
      expect(firstLegMatchingEvent(event, trip), _italy5to10);
    });

    test('an Italian event during the French dates does not', () {
      final event = _event(
        country: 'IT',
        start: DateTime(2026, 12, 2, 19),
        end: DateTime(2026, 12, 2, 23),
      );
      expect(eventMatchesTrip(event, trip), isFalse);
    });

    test('a French event in another city still matches the Paris leg — '
        'no name comparison per leg', () {
      final event = _event(
        country: 'FR',
        city: 'Reims',
        start: DateTime(2026, 12, 2, 19),
        end: DateTime(2026, 12, 2, 23),
      );
      expect(eventMatchesTrip(event, trip), isTrue);
    });

    test('a trip without loaded destinations keeps the original city rule', () {
      final legacy = _trip(city: 'Paris');
      final event = _event(
        country: 'FR',
        city: 'Reims',
        start: DateTime(2026, 12, 2, 19),
        end: DateTime(2026, 12, 2, 23),
      );
      expect(eventMatchesTrip(event, legacy), isFalse);
    });
  });

  group('formatLegDateRange', () {
    test('same month', () {
      expect(
        formatLegDateRange(DateTime(2026, 12, 1), DateTime(2026, 12, 5)),
        '1–5 Dec',
      );
    });
    test('across months', () {
      expect(
        formatLegDateRange(DateTime(2026, 11, 28), DateTime(2026, 12, 2)),
        '28 Nov – 2 Dec',
      );
    });
  });

  group('models', () {
    test('TripDestination reads the joined city name and writes RPC json', () {
      final leg = TripDestination.fromJson({
        'trip_id': 't1',
        'position': 0,
        'country_code': 'FR',
        'city_id': _paris,
        'start_date': '2026-12-01',
        'end_date': '2026-12-05',
        'cities': {'name': 'Paris'},
      });
      expect(leg.cityName, 'Paris');
      expect(leg.toRpcJson(), {
        'country_code': 'FR',
        'city_id': _paris,
        'start_date': '2026-12-01',
        'end_date': '2026-12-05',
      });
    });

    test('TripMember: owner has no member id; label falls back', () {
      final owner = TripMember.fromRow({
        'member_id': null,
        'user_id': 'u1',
        'status': 'owner',
        'invited_by': null,
        'username': 'anna',
        'display_name': null,
        'avatar_url': null,
      });
      expect(owner.status, TripMemberStatus.owner);
      expect(owner.memberId, isNull);
      expect(owner.label, '@anna');
    });

    test('trip invitation notifications parse with their trip fields', () {
      final n = AppNotification.tryFromRow({
        'id': 'n1',
        'type': 'trip_invite_received',
        'subject_type': 'planned_trip_member',
        'subject_id': 'm1',
        'is_read': false,
        'created_at': '2026-10-28T12:00:00+00:00',
        'trip_id': 't1',
        'trip_title': 'Paris and Italy',
        'trip_start_date': '2026-12-01',
        'trip_end_date': '2026-12-10',
        'trip_member_status': 'pending',
      });
      expect(n?.type, AppNotificationType.tripInviteReceived);
      expect(n?.tripTitle, 'Paris and Italy');
      expect(n?.tripMemberStatus, 'pending');
    });
  });
}
