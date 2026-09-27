import 'dart:math' as math;

import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../models/venue_entry.dart';
import 'models/passport_stamp_item.dart';
import 'passport_stamp_source.dart';

/// The Passport's one continuous booklet — every stamp across every year
/// (capped to the last 5 calendar years, see [buildPassportVolumes]), never
/// split into separate per-year books any more. [year] is always null now
/// (kept as a field, not removed, only because [PassportCoverFace]/
/// [PassportDataPage]/[PassportOpenBookFrame] already branch on it for the
/// pre-existing "no entries yet" empty state — see those files' own
/// remaining `volume.year == null` checks). Built once per load by
/// [buildPassportVolumes]; everything a cover face or the data page needs
/// to render is already computed here, so neither widget re-derives stats
/// from the raw entry lists itself.
class PassportVolume {
  /// Always null post-refactor — see this class's own doc comment.
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
}

/// Builds the single continuous booklet volume — every restaurant visit,
/// hotel stay, and confirmed event attendance across the last 5 calendar
/// years (this year plus the 4 before it), oldest-first internally (the
/// stamp pages themselves group and order newest-first, see
/// [buildYearGroupedStampPages]). Returns an empty list only when there is
/// truly nothing to show at all (no entries, or every entry falls outside
/// the 5-year window) — the caller renders the existing "no visits yet"
/// cover-only state in that case, exactly as it did for a genuinely empty
/// passport before this refactor.
///
/// Previously returned one volume per YEAR (plus a "COMPLETE" volume
/// containing everything) — a stack of separate yearly booklets you'd
/// swipe between on the cover. That's gone: one booklet, one cover, all
/// stamps together. Year-grouping is kept, just moved entirely into how
/// the stamp pages themselves are laid out
/// ([buildYearGroupedStampPages]'s own per-year page breaks and corner
/// labels), not into a separate volume per year.
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

  // "Tot vijf jaar terug" — this year plus the 4 before it, a real data
  // cutoff, not the old cover-stack's purely VISUAL 5-peek cap
  // (PassportCoverStackState._maxPeek, which never actually hid data —
  // every year beyond the front 6 was still reachable by swiping). Stamps
  // older than this window are dropped from the booklet entirely.
  final cutoffYear = DateTime.now().year - 4;
  final items = allItems.where((item) => item.date.year >= cutoffYear).toList();
  if (items.isEmpty) return [];

  final firstYear = items.map((item) => item.date.year).reduce(math.min);
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

  return [
    PassportVolume(
      year: null,
      items: items,
      countryCodes: countryCodes,
      stars: stars,
      collectionFirstYear: firstYear,
    ),
  ];
}
