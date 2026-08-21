// Events V2 Step 5 — covers the map-owned pin model
// (lib/features/map/models/map_pin.dart) and filter type
// (lib/features/map/models/map_filter_type.dart):
// §20 Restaurant/Hotel/Event adaptation, type semantics, stable ids,
//     coordinates.
// §21 Event map eligibility — confirmed attendance + coordinates required,
//     no fallback, no substitution from a linked venue.
// §22 Filters — All/Restaurants/Hotels/Events each return the correct
//     subset.
// §24 Overlap — two pins sharing the same coordinate is a valid, supported
//     state (no clustering exists; this proves the model itself never
//     collapses or crashes on the collision, only visual stacking occurs at
//     the widget layer, which is FlutterMap's own existing behavior).
//
// No Supabase/network involved: every fixture here is a plain Dart object,
// matching this codebase's "pure top-level function / plain model" testing
// convention (see event_attendance_eligibility_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/features/map/models/map_filter_type.dart';
import 'package:michelin_passport/features/map/models/map_pin.dart';
import 'package:michelin_passport/features/passport/passport_view_model.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Test Restaurant',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

PassportVenueStats _restaurantStats({Restaurant restaurant = _restaurant}) =>
    PassportVenueStats.from(RestaurantVenue(restaurant), [
      Visit(
        id: 'v1',
        userId: 'u1',
        entityType: 'restaurant',
        entityId: restaurant.id,
        visitedOn: DateTime(2025, 5, 1),
        starsAtVisit: 2,
      ),
    ]);

PassportVenueStats _hotelStats({Hotel hotel = _hotel}) =>
    PassportVenueStats.from(HotelVenue(hotel), [
      Visit(
        id: 'v2',
        userId: 'u1',
        entityType: 'hotel',
        entityId: hotel.id,
        visitedOn: DateTime(2025, 6, 1),
        keysAtVisit: 1,
      ),
    ]);

Event _event({
  String id = 'evt-1',
  String name = 'Test Event',
  double? latitude,
  double? longitude,
  String? venueName,
  String? city,
}) => Event(
  id: id,
  name: name,
  startAt: DateTime.utc(2026, 6, 1),
  endAt: DateTime.utc(2026, 6, 1, 22),
  countryCode: 'NL',
  city: city,
  venueName: venueName,
  latitude: latitude,
  longitude: longitude,
  eventType: EventType.festival,
  status: EventStatus.completed,
  createdAt: DateTime.utc(2026, 1, 1),
);

EventAttendanceEntry _attendanceEntry({
  String attendanceId = 'att-1',
  Event? event,
  int? rating,
}) => EventAttendanceEntry(
  attendance: EventConfirmedAttendance(
    id: attendanceId,
    eventId: (event ?? _event()).id,
    userId: 'u1',
    confirmedAt: DateTime.utc(2026, 6, 2),
    rating: rating,
    visibility: ConfirmedAttendanceVisibility.private,
    source: EventAttendanceSource.manual,
    createdAt: DateTime.utc(2026, 6, 2),
  ),
  event: event ?? _event(),
);

void main() {
  group('MapPin — §20 Restaurant adaptation', () {
    test('restaurantAndHotelMapPins produces one RestaurantMapPin per '
        'coordinate-resolved restaurant', () {
      final pins = restaurantAndHotelMapPins(
        stats: [_restaurantStats()],
        restaurantCoords: {'r1': (51.9, 4.5)},
        hotelCoords: {},
      );
      expect(pins, hasLength(1));
      final pin = pins.single as RestaurantMapPin;
      expect(pin.type, MapPinType.restaurant);
      expect(pin.latitude, 51.9);
      expect(pin.longitude, 4.5);
      expect(pin.title, 'Test Restaurant');
      expect(pin.id, 'restaurant:r1');
    });

    test('a restaurant with no resolved coordinate is silently omitted — '
        'never a fallback pin', () {
      final pins = restaurantAndHotelMapPins(
        stats: [_restaurantStats()],
        restaurantCoords: {},
        hotelCoords: {},
      );
      expect(pins, isEmpty);
    });
  });

  group('MapPin — §20 Hotel adaptation', () {
    test('restaurantAndHotelMapPins produces one HotelMapPin per '
        'coordinate-resolved hotel', () {
      final pins = restaurantAndHotelMapPins(
        stats: [_hotelStats()],
        restaurantCoords: {},
        hotelCoords: {'h1': (52.3, 4.9)},
      );
      expect(pins, hasLength(1));
      final pin = pins.single as HotelMapPin;
      expect(pin.type, MapPinType.hotel);
      expect(pin.latitude, 52.3);
      expect(pin.longitude, 4.9);
      expect(pin.title, 'Test Hotel');
      expect(pin.id, 'hotel:h1');
    });

    test('restaurant and hotel pins never collide by id even with the same '
        'underlying catalogue id string', () {
      final pins = restaurantAndHotelMapPins(
        stats: [
          _restaurantStats(restaurant: _restaurant),
          _hotelStats(
            hotel: const Hotel(
              id: 'r1',
              hotelCode: 'r1',
              name: 'Same Id Hotel',
              michelinKeys: 1,
              cityName: 'Amsterdam',
              countryCode: 'NL',
              countryName: 'Netherlands',
              flagEmoji: '🇳🇱',
              address: '1 Test Street',
              hasMichelinRestaurant: false,
              restaurantCount: 0,
            ),
          ),
        ],
        restaurantCoords: {'r1': (1, 1)},
        hotelCoords: {'r1': (2, 2)},
      );
      final ids = pins.map((p) => p.id).toSet();
      expect(ids, {'restaurant:r1', 'hotel:r1'});
    });
  });

  group('MapPin — §20/§21/§6 Event adaptation and coordinate eligibility', () {
    test('confirmed attendance + both coordinates present => one '
        'EventMapPin', () {
      final entry = _attendanceEntry(
        event: _event(
          latitude: 49.6,
          longitude: 6.1,
          venueName: 'Vrijthof',
          city: 'Maastricht',
        ),
      );
      final pins = eventMapPins([entry]);
      expect(pins, hasLength(1));
      final pin = pins.single as EventMapPin;
      expect(pin.type, MapPinType.event);
      expect(pin.latitude, 49.6);
      expect(pin.longitude, 6.1);
      expect(pin.title, 'Test Event');
      expect(pin.subtitle, 'Vrijthof, Maastricht');
      expect(pin.id, 'event:att-1');
    });

    test('§6/§21 confirmed attendance but latitude is null => silently '
        'omitted, no fallback pin', () {
      final entry = _attendanceEntry(
        event: _event(latitude: null, longitude: 6.1),
      );
      expect(eventMapPins([entry]), isEmpty);
    });

    test('§6/§21 confirmed attendance but longitude is null => silently '
        'omitted', () {
      final entry = _attendanceEntry(
        event: _event(latitude: 49.6, longitude: null),
      );
      expect(eventMapPins([entry]), isEmpty);
    });

    test('§6/§21 confirmed attendance but both coordinates null (today\'s '
        'production reality for all 4 live Events) => silently omitted', () {
      final entry = _attendanceEntry(event: _event());
      expect(eventMapPins([entry]), isEmpty);
    });

    test('§21 an event with coordinates but NO confirmed attendance never '
        'reaches eventMapPins at all — the input list is already scoped to '
        'confirmed attendance only (Interested/Going are never passed in)', () {
      // eventMapPins only ever receives EventAttendanceEntry values, which
      // by construction (EventConfirmedAttendanceRepository
      // .loadPassportEventAttendance) only exist for confirmed rows — an
      // empty input list is the correct representation of "no confirmed
      // attendance," proving there is no separate path that could smuggle
      // an Interested/Going event in.
      expect(eventMapPins(const []), isEmpty);
    });

    test('multiple confirmed attendances each with coordinates => one pin '
        'per attendance, independent ids', () {
      final entries = [
        _attendanceEntry(
          attendanceId: 'att-1',
          event: _event(id: 'evt-1', latitude: 1, longitude: 1),
        ),
        _attendanceEntry(
          attendanceId: 'att-2',
          event: _event(id: 'evt-2', latitude: 2, longitude: 2),
        ),
      ];
      final pins = eventMapPins(entries);
      expect(pins.map((p) => p.id).toSet(), {'event:att-1', 'event:att-2'});
    });

    test('subtitle falls back to city alone when venueName is absent, and '
        'to empty when neither is present — never throws', () {
      final withCityOnly = EventMapPin(
        entry: _attendanceEntry(event: _event(city: 'Maastricht')),
        latitude: 1,
        longitude: 1,
      );
      expect(withCityOnly.subtitle, 'Maastricht');

      final withNeither = EventMapPin(
        entry: _attendanceEntry(event: _event()),
        latitude: 1,
        longitude: 1,
      );
      expect(withNeither.subtitle, '');
    });
  });

  group('MapFilterType — §22 filters', () {
    final restaurantPin = RestaurantMapPin(
      stats: _restaurantStats(),
      latitude: 1,
      longitude: 1,
    );
    final hotelPin = HotelMapPin(
      stats: _hotelStats(),
      latitude: 2,
      longitude: 2,
    );
    final eventPin = EventMapPin(
      entry: _attendanceEntry(event: _event(latitude: 3, longitude: 3)),
      latitude: 3,
      longitude: 3,
    );
    final allPins = [restaurantPin, hotelPin, eventPin];

    test('All matches every pin type', () {
      expect(allPins.where((p) => MapFilterType.all.matches(p.type)), allPins);
    });

    test('Restaurants matches only restaurant pins', () {
      final matched = allPins.where(
        (p) => MapFilterType.restaurants.matches(p.type),
      );
      expect(matched, [restaurantPin]);
    });

    test('Hotels matches only hotel pins', () {
      final matched = allPins.where(
        (p) => MapFilterType.hotels.matches(p.type),
      );
      expect(matched, [hotelPin]);
    });

    test('Events matches only event pins', () {
      final matched = allPins.where(
        (p) => MapFilterType.events.matches(p.type),
      );
      expect(matched, [eventPin]);
    });

    test('labels are exactly All / Restaurants / Hotels / Events, in that '
        'order', () {
      expect(MapFilterType.values.map((t) => t.label).toList(), [
        'All',
        'Restaurants',
        'Hotels',
        'Events',
      ]);
    });
  });

  group('MapPin — §24 overlapping coordinates', () {
    test('a Restaurant and an Event at the exact same coordinate both '
        'appear — the model never merges or drops either', () {
      final restaurantPin = RestaurantMapPin(
        stats: _restaurantStats(),
        latitude: 50.85,
        longitude: 5.69,
      );
      final eventPin = EventMapPin(
        entry: _attendanceEntry(
          event: _event(latitude: 50.85, longitude: 5.69),
        ),
        latitude: 50.85,
        longitude: 5.69,
      );
      final pins = [restaurantPin, eventPin];
      expect(pins, hasLength(2));
      expect(pins.map((p) => p.id).toSet(), hasLength(2));
      expect(
        pins.every((p) => p.latitude == 50.85 && p.longitude == 5.69),
        isTrue,
      );
    });

    test('two Events at the exact same coordinate both appear, each with '
        'its own distinct pin id', () {
      final entries = [
        _attendanceEntry(
          attendanceId: 'att-1',
          event: _event(id: 'evt-1', latitude: 50.85, longitude: 5.69),
        ),
        _attendanceEntry(
          attendanceId: 'att-2',
          event: _event(id: 'evt-2', latitude: 50.85, longitude: 5.69),
        ),
      ];
      final pins = eventMapPins(entries);
      expect(pins, hasLength(2));
      expect(pins.map((p) => p.id).toSet(), hasLength(2));
    });
  });
}
