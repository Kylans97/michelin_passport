import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../models/venue_entry.dart';
import 'models/passport_stamp_item.dart';
import 'passport_stamp_source.dart';

/// One "book" in the Passport stack — either the complete passport
/// (`year == null`, every entry ever recorded) or one calendar year's own
/// volume. Built once per load by [buildPassportVolumes]; everything a
/// cover face or the data page needs to render is already computed here,
/// so neither widget re-derives stats from the raw entry lists itself.
class PassportVolume {
  /// Null for the complete passport; a calendar year for a yearly volume.
  final int? year;

  /// Every stamp in this volume's scope, oldest first — unused by Round 1
  /// (cover + data page only) but computed alongside the rest so Round 2's
  /// stamp pages don't need a second pass over the same source lists.
  final List<PassportStampItem> items;

  /// Total stamps in scope — one per visit/stay/confirmed attendance, not
  /// deduplicated per venue, matching how the stamp system itself already
  /// counts (see PassportStampItem's own doc comment). This is
  /// [items.length], kept as its own field so call sites read intent
  /// ("ENTRIES") rather than list length.
  int get entries => items.length;

  /// Distinct country codes across every stamp in scope, sorted for stable
  /// display order (the design spec doesn't specify an order for the
  /// COUNTRIES VISITED chip row, and an unstable order would make the
  /// chips visibly reshuffle on every reload).
  final List<String> countryCodes;

  int get countries => countryCodes.length;

  /// Sum of Michelin stars AT THE TIME OF VISIT across every restaurant
  /// stamp in scope (never the restaurant's current award — same
  /// historical-snapshot rule every other stamp/visit surface in this app
  /// already follows). Hotel keys and event types don't contribute here —
  /// literal reading of the design spec's single "STARS" field, which
  /// names stars specifically, not "awards" generically. Deliberately a
  /// SUM over every stamp, not a per-venue dedupe: "ENTRIES" already
  /// counts every visit, not every venue, so "STARS" stays consistent
  /// with that same per-stamp counting rather than switching metrics
  /// mid-page. Disclosed as an interpretive call, not asked about.
  final int stars;

  /// The earliest year with at least one entry across the WHOLE passport
  /// (not just this volume) — used only by the complete passport's own
  /// "VALID: {firstYear} – present" field. Null when there are no entries
  /// at all.
  final int? collectionFirstYear;

  const PassportVolume({
    required this.year,
    required this.items,
    required this.countryCodes,
    required this.stars,
    required this.collectionFirstYear,
  });

  String get label => year == null ? 'COMPLETE' : '$year';
}

/// Builds the complete-passport volume plus one volume per year that has
/// at least one entry (restaurant visit, hotel stay, or confirmed event
/// attendance), newest year first. Empty (`entries.isEmpty &&
/// eventEntries.isEmpty`) returns an empty list — the caller renders the
/// existing "no visits yet" cover-only state instead of any volume.
List<PassportVolume> buildPassportVolumes({
  required List<VenueEntry> entries,
  required List<EventAttendanceEntry> eventEntries,
}) {
  final restaurantItems = buildRestaurantStampItems(entries);
  final hotelItems = buildHotelStampItems(entries);
  final eventItems = buildEventStampItems(eventEntries);
  final allItems = [...restaurantItems, ...hotelItems, ...eventItems]
    ..sort((a, b) => a.date.compareTo(b.date));

  if (allItems.isEmpty) return [];

  final years = allItems.map((item) => item.date.year).toSet().toList()
    ..sort();
  final firstYear = years.first;

  PassportVolume volumeFor(int? year) {
    final items = year == null
        ? allItems
        : allItems.where((item) => item.date.year == year).toList();
    final countryCodes =
        items
            .map((item) => item.countryCode)
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final stars = items
        .whereType<RestaurantStampItem>()
        .fold<int>(0, (sum, item) => sum + (item.stars ?? 0));
    return PassportVolume(
      year: year,
      items: items,
      countryCodes: countryCodes,
      stars: stars,
      collectionFirstYear: firstYear,
    );
  }

  return [
    volumeFor(null),
    for (final year in years.reversed) volumeFor(year),
  ];
}
