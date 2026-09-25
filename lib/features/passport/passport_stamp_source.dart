import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import 'models/passport_stamp_item.dart';

/// The Restaurant-filter stamp list: one [RestaurantStampItem] per visit
/// (not per venue — see [PassportStampItem]'s own doc comment), across
/// every [RestaurantVenue] in [entries], scoped to [year] ("All time"
/// when null). Oldest visit first — see [buildStampItems]'s own doc
/// comment for why ascending, not the rest of Passport's usual
/// newest-first order.
List<PassportStampItem> buildRestaurantStampItems(
  List<VenueEntry> entries, {
  int? year,
}) {
  final items = <PassportStampItem>[];
  for (final entry in entries) {
    final venue = entry.venue;
    if (venue is! RestaurantVenue) continue;
    for (final visit in entry.visitsInYear(year)) {
      items.add(RestaurantStampItem(restaurant: venue.restaurant, visit: visit));
    }
  }
  return _sortOldestFirst(items);
}

/// The Hotel-filter equivalent of [buildRestaurantStampItems].
List<PassportStampItem> buildHotelStampItems(
  List<VenueEntry> entries, {
  int? year,
}) {
  final items = <PassportStampItem>[];
  for (final entry in entries) {
    final venue = entry.venue;
    if (venue is! HotelVenue) continue;
    for (final visit in entry.visitsInYear(year)) {
      items.add(HotelStampItem(hotel: venue.hotel, visit: visit));
    }
  }
  return _sortOldestFirst(items);
}

/// The Events-filter equivalent — one [EventStampItem] per confirmed
/// attendance in [year] ("All time" when null).
List<PassportStampItem> buildEventStampItems(
  List<EventAttendanceEntry> entries, {
  int? year,
}) {
  final items = [
    for (final entry in entries)
      if (year == null || entry.event.startDate.year == year)
        EventStampItem(entry),
  ];
  return _sortOldestFirst(items);
}

List<PassportStampItem> _sortOldestFirst(List<PassportStampItem> items) {
  final sorted = List<PassportStampItem>.from(items);
  sorted.sort((a, b) => a.date.compareTo(b.date));
  return sorted;
}

/// One of the (exactly) 4 positions on a Passport page.
sealed class PassportStampSlot {
  const PassportStampSlot();
}

class FilledStampSlot extends PassportStampSlot {
  final PassportStampItem item;
  const FilledStampSlot(this.item);
}

/// The one open, dashed "Your next stamp" slot — always exactly one
/// across the whole collection, always on the last page. See
/// [paginateStamps]'s own doc comment for the full placement rule.
class NextStampSlot extends PassportStampSlot {
  const NextStampSlot();
}

/// A slot with nothing in it at all — not even the dashed "next stamp"
/// outline. A page can have several of these (when its last page has few
/// real stamps) but never more than [NextStampSlot] — the reserved
/// "next" indicator is always exactly one slot, not "every remaining
/// slot."
class BlankStampSlot extends PassportStampSlot {
  const BlankStampSlot();
}

/// Groups [items] (already oldest-first — see [buildRestaurantStampItems]
/// et al.) into pages of [perPage] stamps each.
///
/// "The last page always has one empty slot": every page up to the
/// second-to-last is exactly [perPage] [FilledStampSlot]s. The LAST page
/// gets exactly one [NextStampSlot] appended after its real stamps, with
/// any further remainder padded as [BlankStampSlot] — UNLESS the final
/// chunk of real stamps already fills a whole page (`items.length %
/// perPage == 0`), in which case a wholly new trailing page is appended
/// holding just that one [NextStampSlot] (a full page, by definition,
/// has no room left for it). [items] must not be empty — Passport's own
/// zero-stamps case renders its pre-existing empty state instead of a
/// page at all (see PassportCollectionBody).
List<List<PassportStampSlot>> paginateStamps(
  List<PassportStampItem> items, {
  int perPage = 4,
}) {
  assert(items.isNotEmpty, 'paginateStamps requires at least one item');
  final pages = <List<PassportStampSlot>>[];
  var i = 0;
  while (i < items.length) {
    final chunk = items.skip(i).take(perPage).toList();
    pages.add([for (final item in chunk) FilledStampSlot(item)]);
    i += perPage;
  }

  if (pages.last.length == perPage) {
    pages.add([const NextStampSlot()]);
  } else {
    pages.last.add(const NextStampSlot());
  }
  while (pages.last.length < perPage) {
    pages.last.add(const BlankStampSlot());
  }
  return pages;
}

/// One stamp page's slots, plus which calendar [year] every stamp on it
/// belongs to — the booklet redesign's stamp pages (Round 2) show that
/// year in a corner label, which a bare `List<PassportStampSlot>` has no
/// way to carry.
class PassportStampPage {
  final int year;
  final List<PassportStampSlot> slots;
  const PassportStampPage({required this.year, required this.slots});
}

/// [paginateStamps]'s own doc comment describes the flat, single-scope
/// case (one Passport filter, one flat run of pages). The booklet's
/// COMPLETE passport instead groups pages by year — "In het complete
/// paspoort zijn pagina's gegroepeerd per jaar (nieuwste eerst) en krijgt
/// elk jaar een nieuwe pagina": every year always starts a fresh page,
/// even when the previous year's last page has room to spare, and years
/// are ordered newest-first (the volume you'd reach first swiping in from
/// the data page is the current year, not the oldest).
///
/// The single "add your next stamp" [NextStampSlot] still belongs on
/// exactly one page for the whole scope, not once per year — so it's
/// appended only to the very last page of the very last (oldest) year
/// group, following [paginateStamps]'s own "a full page needs a wholly
/// new trailing page" edge case exactly.
///
/// [itemsOldestFirst] does not need to already be sorted per year — only
/// oldest-first overall (matching every stamp-item builder's own output);
/// this groups by year first and each year's own bucket naturally
/// inherits that same oldest-first order for its stamps.
///
/// A single-year [PassportVolume] (a yearly volume, not the complete
/// passport) is not a special case here — it's simply the one-year-group
/// case this same function already produces, so both scopes share this
/// one implementation.
List<PassportStampPage> buildYearGroupedStampPages(
  List<PassportStampItem> itemsOldestFirst, {
  int perPage = 4,
}) {
  if (itemsOldestFirst.isEmpty) return [];

  final byYear = <int, List<PassportStampItem>>{};
  for (final item in itemsOldestFirst) {
    byYear.putIfAbsent(item.date.year, () => []).add(item);
  }
  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

  final pages = <PassportStampPage>[];
  for (final year in years) {
    final yearItems = byYear[year]!;
    var i = 0;
    while (i < yearItems.length) {
      final chunk = yearItems.skip(i).take(perPage).toList();
      pages.add(
        PassportStampPage(
          year: year,
          slots: [for (final item in chunk) FilledStampSlot(item)],
        ),
      );
      i += perPage;
    }
  }

  final lastYear = pages.last.year;
  if (pages.last.slots.length == perPage) {
    pages.add(PassportStampPage(year: lastYear, slots: [const NextStampSlot()]));
  } else {
    pages.last.slots.add(const NextStampSlot());
  }
  while (pages.last.slots.length < perPage) {
    pages.last.slots.add(const BlankStampSlot());
  }
  return pages;
}
