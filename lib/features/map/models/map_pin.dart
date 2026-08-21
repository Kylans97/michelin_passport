// Events V2 Step 5 — the map-owned pin model. My Map needs to plot three
// different kinds of history (restaurant visits, hotel stays, confirmed
// Event attendance) on one shared FlutterMap, but those three domain types
// (PassportVenue, PassportVenue, Event) have nothing in common today and
// deliberately never will — PassportVenue stays Restaurant/Hotel-only (see
// its own doc comment and EventAttendanceEntry's doc comment, both of
// which name "My Map" explicitly as a reason Events must stay additive
// rather than becoming a third PassportVenue case, so as not to force
// every one of that sealed type's ~20 exhaustive switch sites to grow an
// Events branch as a side effect of this step).
//
// MapPin is this screen's own small, framework-independent adapter layer
// instead: one sealed type wrapping whichever already-loaded domain object
// a pin represents (PassportVenueStats for Restaurant/Hotel,
// EventAttendanceEntry for Event) plus the resolved coordinate. No Flutter
// import here — no Widget, no BuildContext — so pin construction and
// filtering stay unit-testable without pumping a widget.
import '../../../data/repositories/event_confirmed_attendance_repository.dart'
    show EventAttendanceEntry;
import '../../../models/hotel.dart';
import '../../../models/passport_venue.dart';
import '../../../models/restaurant.dart';
import '../../passport/passport_view_model.dart' show PassportVenueStats;

/// Which kind of pin this is — drives icon selection ([VenuePin]) and
/// filter matching ([MapFilterType.matches]). Deliberately not reusing
/// [PassportVenue]'s own runtime type for this: a pin's type also needs an
/// `event` case PassportVenue can never have.
enum MapPinType { restaurant, hotel, event }

/// One plottable point on My Map. Each variant carries the exact
/// already-loaded domain object its own tap-through/preview needs — this
/// type is purely an adapter for shared iteration/filtering/plotting, never
/// a replacement for PassportVenueStats or EventAttendanceEntry, and never
/// itself sent to Supabase or serialized.
sealed class MapPin {
  const MapPin();

  /// Stable and unique across every pin on the map at once (never just the
  /// underlying Restaurant/Hotel/Event id alone, which could theoretically
  /// collide across the three id spaces).
  String get id;
  MapPinType get type;
  String get title;
  String get subtitle;
  double get latitude;
  double get longitude;
}

class RestaurantMapPin extends MapPin {
  final PassportVenueStats stats;
  @override
  final double latitude;
  @override
  final double longitude;

  const RestaurantMapPin({
    required this.stats,
    required this.latitude,
    required this.longitude,
  });

  Restaurant get restaurant => (stats.venue as RestaurantVenue).restaurant;

  @override
  String get id => 'restaurant:${restaurant.id}';
  @override
  MapPinType get type => MapPinType.restaurant;
  @override
  String get title => restaurant.name;
  @override
  String get subtitle => '${restaurant.cityName}, ${restaurant.countryName}';
}

class HotelMapPin extends MapPin {
  final PassportVenueStats stats;
  @override
  final double latitude;
  @override
  final double longitude;

  const HotelMapPin({
    required this.stats,
    required this.latitude,
    required this.longitude,
  });

  Hotel get hotel => (stats.venue as HotelVenue).hotel;

  @override
  String get id => 'hotel:${hotel.id}';
  @override
  MapPinType get type => MapPinType.hotel;
  @override
  String get title => hotel.name;
  @override
  String get subtitle => '${hotel.cityName}, ${hotel.countryName}';
}

class EventMapPin extends MapPin {
  final EventAttendanceEntry entry;
  @override
  final double latitude;
  @override
  final double longitude;

  const EventMapPin({
    required this.entry,
    required this.latitude,
    required this.longitude,
  });

  /// The confirmed-attendance id, not the Event id — kept distinct from
  /// [id] so two different confirmed attendances could never collide even
  /// in a hypothetical future where a user could confirm the same event
  /// twice (they can't — `event_confirmed_attendance` has
  /// `unique(event_id, user_id)` — but this pin id is scoped to the
  /// attendance row on principle, matching how the pin's whole existence is
  /// gated on that row, not on the Event alone).
  @override
  String get id => 'event:${entry.attendance.id}';
  @override
  MapPinType get type => MapPinType.event;
  @override
  String get title => entry.event.name;
  @override
  String get subtitle {
    final venueName = entry.event.venueName;
    final city = entry.event.city;
    if (venueName != null && venueName.isNotEmpty) {
      return city != null && city.isNotEmpty ? '$venueName, $city' : venueName;
    }
    return city ?? '';
  }
}

/// Adapts already-loaded Restaurant/Hotel Passport stats plus their
/// separately-loaded coordinates into map pins — one pin per venue that has
/// a resolved coordinate, exactly mirroring [VisitedMapScreen]'s
/// pre-Step-5 `_coordsOf`/`plottable` logic (multi-visit collapse already
/// happened upstream, in [PassportFilterResult.of] itself, so there is
/// nothing left for this adapter to collapse). A venue with no resolved
/// coordinate is silently omitted — the same "coordinates are catalogue
/// data, never guessed" rule this step's Event side also follows.
List<MapPin> restaurantAndHotelMapPins({
  required List<PassportVenueStats> stats,
  required Map<String, (double, double)> restaurantCoords,
  required Map<String, (double, double)> hotelCoords,
}) {
  final pins = <MapPin>[];
  for (final entry in stats) {
    switch (entry.venue) {
      case RestaurantVenue(:final restaurant):
        final coords = restaurantCoords[restaurant.id];
        if (coords != null) {
          pins.add(
            RestaurantMapPin(
              stats: entry,
              latitude: coords.$1,
              longitude: coords.$2,
            ),
          );
        }
      case HotelVenue(:final hotel):
        final coords = hotelCoords[hotel.id];
        if (coords != null) {
          pins.add(
            HotelMapPin(
              stats: entry,
              latitude: coords.$1,
              longitude: coords.$2,
            ),
          );
        }
    }
  }
  return pins;
}

/// Adapts confirmed Event attendance into map pins. Events V2 Step 5 §6:
/// eligible for a pin only when the Event's OWN snapshotted
/// latitude/longitude are both non-null — never substituted from a linked
/// Restaurant/Hotel/Private Chef, never a host's or participant's
/// coordinates, never a city center, never a runtime geocoder. An Event
/// missing either coordinate is silently omitted here: the confirmed
/// attendance itself is untouched (Passport and Event Detail remain fully
/// reachable elsewhere), only the map pin doesn't render.
List<MapPin> eventMapPins(List<EventAttendanceEntry> entries) => [
  for (final entry in entries)
    if (entry.event.latitude != null && entry.event.longitude != null)
      EventMapPin(
        entry: entry,
        latitude: entry.event.latitude!,
        longitude: entry.event.longitude!,
      ),
];
