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
