import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';

/// One ink stamp on a Passport page — one per individual visit/stay/
/// confirmed attendance, NOT deduplicated per venue the way the previous
/// card-based list was (see [PassportFilterResult] in passport_view_model
/// .dart, still used elsewhere). A restaurant visited three times gets
/// three stamps, exactly like a real passport re-stamping the same border
/// on a second crossing — that repetition is the point of the metaphor,
/// so [PassportFilterResult]'s "one row per venue, newest visit wins" isn't
/// reused here; see passport_stamp_source.dart for the flattening logic
/// that builds these instead.
///
/// [id] is what passport_stamp_style.dart hashes for every deterministic
/// choice (variant, ink, rotation, position jitter) — it must be a value
/// that already uniquely and stably identifies this one visit/stay/
/// attendance (a `visits`/`event_confirmed_attendance` row id), never
/// something derived from display data that could collide or change.
sealed class PassportStampItem {
  const PassportStampItem();

  String get id;
  String get venueName;

  /// May be empty — an Event's `city` column is nullable (see event.dart);
  /// stamp rendering treats an empty city the same as a missing one
  /// (omits that segment) rather than printing a blank " · ".
  String get cityName;
  String get countryCode;
  DateTime get date;
}

class RestaurantStampItem extends PassportStampItem {
  final Restaurant restaurant;
  final Visit visit;

  const RestaurantStampItem({required this.restaurant, required this.visit});

  @override
  String get id => visit.id;
  @override
  String get venueName => restaurant.name;
  @override
  String get cityName => restaurant.cityName;
  @override
  String get countryCode => restaurant.countryCode;
  @override
  DateTime get date => visit.visitedOn;

  /// Stars AT THIS VISIT, not the restaurant's current award — matching
  /// [PassportVenueStats.awardAtLatestVisit]'s own established reasoning
  /// (historical experiences stay meaningful even after a guide changes).
  /// Null or 0 both mean "no star glyphs drawn" for this one stamp — see
  /// passport_stamp_painters.dart's own note on why that doesn't conflict
  /// with `michelin_stars = 0` being a valid award elsewhere.
  int? get stars => visit.starsAtVisit;
}

class HotelStampItem extends PassportStampItem {
  final Hotel hotel;
  final Visit visit;

  const HotelStampItem({required this.hotel, required this.visit});

  @override
  String get id => visit.id;
  @override
  String get venueName => hotel.name;
  @override
  String get cityName => hotel.cityName;
  @override
  String get countryCode => hotel.countryCode;
  @override
  DateTime get date => visit.visitedOn;

  /// Keys AT THIS STAY — same reasoning as [RestaurantStampItem.stars].
  int? get keys => visit.keysAtVisit;
}

class EventStampItem extends PassportStampItem {
  final EventAttendanceEntry entry;

  const EventStampItem(this.entry);

  @override
  String get id => entry.attendance.id;
  @override
  String get venueName => entry.event.name;
  @override
  String get cityName => entry.event.city ?? '';
  @override
  String get countryCode => entry.event.countryCode;
  @override
  DateTime get date => entry.event.startDate;

  /// The event type stands in for an award row on this stamp variant
  /// (e.g. "DINNER", "TASTING") — an Event has no Michelin-star/Key
  /// concept of its own, matching [PassportEventCard]'s own established
  /// "no awardRow, ever" rule.
  String get eventTypeLabel => entry.event.eventType.label.toUpperCase();
}
