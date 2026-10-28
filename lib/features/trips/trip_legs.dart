import '../../core/utils/event_time.dart' show compareCalendarDates;
import '../../models/passport_venue.dart';
import '../../models/planned_trip.dart';
import '../../models/resolved_planned_venue.dart';
import '../../models/trip_destination.dart';

/// Pure helpers for a trip's legs (planned_trip_destinations,
/// 20261021120000) — no Supabase, so they're testable on their own.

/// The trip's legs; a trip whose destinations weren't loaded (a server
/// without that migration) has exactly one, its own country.
List<TripDestination> effectiveLegs(PlannedTrip trip) =>
    trip.destinations.isNotEmpty
    ? trip.destinations
    : [TripDestination(countryCode: trip.countryCode)];

DateTime legStart(PlannedTrip trip, TripDestination leg) =>
    leg.startDate ?? trip.startDate;

DateTime legEnd(PlannedTrip trip, TripDestination leg) =>
    leg.endDate ?? trip.endDate;

/// The catalogue scope of some legs, for the venue pickers: whole-country
/// legs contribute a country code, city legs a city id. Codes and ids only.
({List<String> countryCodes, List<String> cityIds}) legScope(
  Iterable<TripDestination> legs,
) {
  final countryCodes = <String>{};
  final cityIds = <String>{};
  for (final leg in legs) {
    final cityId = leg.cityId;
    if (cityId == null) {
      countryCodes.add(leg.countryCode.toUpperCase());
    } else {
      cityIds.add(cityId);
    }
  }
  return (countryCodes: countryCodes.toList(), cityIds: cityIds.toList());
}

bool _venueInLeg(PassportVenue venue, TripDestination leg) {
  final (countryCode, cityId) = switch (venue) {
    RestaurantVenue(:final restaurant) => (
      restaurant.countryCode,
      restaurant.cityId,
    ),
    HotelVenue(:final hotel) => (hotel.countryCode, hotel.cityId),
  };
  final legCity = leg.cityId;
  if (legCity != null) return cityId == legCity;
  return countryCode.toUpperCase() == leg.countryCode.toUpperCase();
}

/// Which leg a planned stay/visit belongs to, by the venue's own place
/// (city id, or country for a whole-country leg) and the plan's start
/// date. Falls back to the first leg whose place matches when no leg's
/// dates contain the plan; null when the venue is in none of the trip's
/// places (planned before a destination was removed, say).
int? legIndexForPlan(PlannedTrip trip, ResolvedPlannedVenue item) {
  final legs = effectiveLegs(trip);
  int? placeOnly;
  for (var i = 0; i < legs.length; i++) {
    if (!_venueInLeg(item.venue, legs[i])) continue;
    placeOnly ??= i;
    final start = item.plan.startDate;
    if (compareCalendarDates(start, legStart(trip, legs[i])) >= 0 &&
        compareCalendarDates(start, legEnd(trip, legs[i])) <= 0) {
      return i;
    }
  }
  return placeOnly;
}

/// "Paris, 🇫🇷 France", or just the country for a whole-country leg — what
/// a leg is called on screen. [countryLabel] resolves a code to "🇫🇷 France".
String legLabel(TripDestination leg, String Function(String) countryLabel) {
  final city = leg.cityName?.trim();
  final country = countryLabel(leg.countryCode);
  return (city != null && city.isNotEmpty) ? '$city, $country' : country;
}

const _monthAbbrev = [
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

/// "1–5 Dec", "28 Nov – 2 Dec" — a leg's dates under its title; the trip's
/// own date line above already carries the year.
String formatLegDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return start.day == end.day
        ? '${start.day} ${_monthAbbrev[start.month - 1]}'
        : '${start.day}–${end.day} ${_monthAbbrev[start.month - 1]}';
  }
  return '${start.day} ${_monthAbbrev[start.month - 1]} – '
      '${end.day} ${_monthAbbrev[end.month - 1]}';
}
