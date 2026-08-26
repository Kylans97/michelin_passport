import '../../data/repositories/event_confirmed_attendance_repository.dart'
    show EventAttendanceEntry;
import '../../models/venue_entry.dart';

/// PROFILE UI REDESIGN V1 — "Your Journey": a compact, TOTAL Chasing
/// Stars journey summary, deliberately distinct from Passport's own
/// restaurant-centric stats (Stars/Restaurants) AND from Passport's own
/// per-category Restaurants/Hotels/Events filtering (`PassportFilterType`
/// — "never merged, never appended below another type"). Two pure,
/// precisely-defined counts:
///
/// - [places]: the total number of unique visited/attended experiences
///   across restaurants, hotels, AND confirmed-attendance events —
///   `passportVenues.length` (restaurants + hotels, one row per venue
///   regardless of visit count, the same [VenueEntry] list Passport's own
///   collection is built from) plus `confirmedEventAttendance.length`
///   (Events with a genuine CONFIRMED attendance — never Going/Interested
///   intent alone, which records an *intention*, not an experience that
///   happened). Neither source can double-count against the other or
///   against itself: `VenueEntry` is already one row per venue, and
///   `event_confirmed_attendance` carries a database-level
///   `unique(event_id, user_id)` constraint. Never wishlist, never
///   planned-but-unvisited venues, never future Trips.
/// - [countries]: unique country codes across those same visited
///   restaurants/hotels AND confirmed-attendance events — never
///   Wishlist, never future Trips, never Interested-only Events, and
///   never a guessed/defaulted code: an entity with no country on file
///   (an empty string, per `Restaurant`/`Hotel`/`Event.countryCode`'s own
///   `?? ''` JSON fallback) is excluded, not counted as "Unknown."
class JourneyMetrics {
  final int places;
  final int countries;

  const JourneyMetrics({required this.places, required this.countries});
}

JourneyMetrics computeJourneyMetrics({
  required List<VenueEntry> passportVenues,
  required List<EventAttendanceEntry> confirmedEventAttendance,
}) {
  final countryCodes = <String>{
    for (final entry in passportVenues) entry.venue.countryCode,
    for (final entry in confirmedEventAttendance) entry.event.countryCode,
  }..removeWhere((code) => code.isEmpty);

  return JourneyMetrics(
    places: passportVenues.length + confirmedEventAttendance.length,
    countries: countryCodes.length,
  );
}
