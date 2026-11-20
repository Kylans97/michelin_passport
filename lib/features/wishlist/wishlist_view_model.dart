import '../../models/event.dart';
import '../../models/journey.dart';
import '../../models/passport_venue.dart';
import '../../models/vineyard.dart';

/// What the Wishlist shows — chosen from one quiet selector at the top
/// rather than a row of chips (product owner, 2026-11-20, "Wishlist,
/// calmer" option A, with option B as its first entry). A kind the member
/// has saved nothing of stays out of the selector.
enum WishlistView {
  everything,
  restaurants,
  hotels,
  events,
  estates,
  trains,
  ships;

  /// The selector's own line ("Restaurants 18 ▾").
  String get label => switch (this) {
    WishlistView.everything => 'Everything',
    WishlistView.restaurants => 'Restaurants',
    WishlistView.hotels => 'Hotels',
    WishlistView.events => 'Events',
    WishlistView.estates => 'Wine estates',
    WishlistView.trains => 'Trains',
    WishlistView.ships => 'Ships',
  };

  /// The row in the selector sheet.
  String get sheetLabel =>
      this == WishlistView.everything ? 'Everything, by place' : label;
}

/// Everything on one member's wishlist, by kind.
class WishlistContents {
  final List<PassportVenue> venues;
  final List<Event> events;
  final List<Vineyard> vineyards;
  final List<Journey> journeys;

  const WishlistContents({
    this.venues = const [],
    this.events = const [],
    this.vineyards = const [],
    this.journeys = const [],
  });

  List<PassportVenue> get restaurants => [
    for (final v in venues)
      if (v is RestaurantVenue) v,
  ];
  List<PassportVenue> get hotels => [
    for (final v in venues)
      if (v is HotelVenue) v,
  ];
  List<Journey> get trains => [
    for (final j in journeys)
      if (j.kind == JourneyKind.train) j,
  ];
  List<Journey> get ships => [
    for (final j in journeys)
      if (j.kind == JourneyKind.ship) j,
  ];

  int countOf(WishlistView view) => switch (view) {
    WishlistView.everything =>
      venues.length + events.length + vineyards.length + journeys.length,
    WishlistView.restaurants => restaurants.length,
    WishlistView.hotels => hotels.length,
    WishlistView.events => events.length,
    WishlistView.estates => vineyards.length,
    WishlistView.trains => trains.length,
    WishlistView.ships => ships.length,
  };

  /// The selector's rows: Everything always, then each kind with at least
  /// one saved — plus [current], so the selected row never disappears.
  List<WishlistView> selectorViews(WishlistView current) => [
    for (final view in WishlistView.values)
      if (view == WishlistView.everything ||
          view == current ||
          countOf(view) > 0)
        view,
  ];
}

/// One saved thing in the by-place view.
class WishlistPlaceItem {
  final WishlistView kind;
  final String name;

  /// The town under the name, when there is one.
  final String? town;

  /// The saved object itself — a [PassportVenue], [Event], [Vineyard] or
  /// [Journey] — so the screen can open its page.
  final Object target;

  const WishlistPlaceItem({
    required this.kind,
    required this.name,
    required this.target,
    this.town,
  });
}

/// One place on the by-place view: a region (or, without one, a town) in
/// a country, with everything saved there.
class WishlistPlaceGroup {
  final String title;

  /// The country's name; null for [isOnTheMove].
  final String? country;
  final List<WishlistPlaceItem> items;

  /// Trains and ships: they cross borders, so they sit together last
  /// instead of under one place.
  final bool isOnTheMove;

  const WishlistPlaceGroup({
    required this.title,
    required this.items,
    this.country,
    this.isOnTheMove = false,
  });
}

/// Groups [contents] by place: region when the record has one, else the
/// town, always within its country (two regions of one name in different
/// countries stay apart). Places with the most saved come first; trains and
/// ships close the list as "On the move". Only stored location fields are
/// used — nothing is matched or inferred by name.
List<WishlistPlaceGroup> groupWishlistByPlace(WishlistContents contents) {
  final groups = <String, _GroupBuilder>{};

  void add({
    required String countryCode,
    required String? countryName,
    required String? region,
    required String? town,
    required WishlistPlaceItem item,
  }) {
    final place = _firstNonEmpty([region, town]) ?? countryName ?? countryCode;
    final key = '$countryCode|${place.toLowerCase()}';
    final group = groups.putIfAbsent(key, () => _GroupBuilder(place));
    group.country ??= _firstNonEmpty([countryName]);
    group.items.add(item);
  }

  for (final venue in contents.venues) {
    switch (venue) {
      case RestaurantVenue(:final restaurant):
        add(
          countryCode: restaurant.countryCode,
          countryName: restaurant.countryName,
          region: restaurant.region,
          town: restaurant.cityName,
          item: WishlistPlaceItem(
            kind: WishlistView.restaurants,
            name: restaurant.name,
            town: _firstNonEmpty([restaurant.cityName]),
            target: venue,
          ),
        );
      case HotelVenue(:final hotel):
        add(
          countryCode: hotel.countryCode,
          countryName: hotel.countryName,
          region: hotel.region,
          town: hotel.cityName,
          item: WishlistPlaceItem(
            kind: WishlistView.hotels,
            name: hotel.name,
            town: _firstNonEmpty([hotel.cityName]),
            target: venue,
          ),
        );
    }
  }
  for (final vineyard in contents.vineyards) {
    add(
      countryCode: vineyard.countryCode,
      countryName: vineyard.countryName,
      region: vineyard.region,
      town: vineyard.city,
      item: WishlistPlaceItem(
        kind: WishlistView.estates,
        name: vineyard.name,
        town: _firstNonEmpty([vineyard.city]),
        target: vineyard,
      ),
    );
  }
  for (final event in contents.events) {
    add(
      countryCode: event.countryCode,
      countryName: null,
      region: null,
      town: event.city,
      item: WishlistPlaceItem(
        kind: WishlistView.events,
        name: event.name,
        town: _firstNonEmpty([event.city]),
        target: event,
      ),
    );
  }

  final placed =
      [
        for (final g in groups.values)
          WishlistPlaceGroup(
            title: g.title,
            country: g.country,
            items: g.items,
          ),
      ]..sort((a, b) {
        final bySize = b.items.length.compareTo(a.items.length);
        if (bySize != 0) return bySize;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

  return [
    ...placed,
    if (contents.journeys.isNotEmpty)
      WishlistPlaceGroup(
        title: 'On the move',
        isOnTheMove: true,
        items: [
          for (final journey in contents.journeys)
            WishlistPlaceItem(
              kind: journey.kind == JourneyKind.train
                  ? WishlistView.trains
                  : WishlistView.ships,
              name: journey.name,
              town: journey.operatorName,
              target: journey,
            ),
        ],
      ),
  ];
}

/// "1 restaurant, 2 wine estates" — what a place holds, kinds in the
/// selector's order.
String wishlistGroupSummary(WishlistPlaceGroup group) {
  final counts = <WishlistView, int>{};
  for (final item in group.items) {
    counts[item.kind] = (counts[item.kind] ?? 0) + 1;
  }
  return [
    for (final view in WishlistView.values)
      if (counts[view] != null) _countPhrase(view, counts[view]!),
  ].join(', ');
}

String _countPhrase(WishlistView view, int n) {
  final (one, many) = switch (view) {
    WishlistView.restaurants => ('restaurant', 'restaurants'),
    WishlistView.hotels => ('hotel', 'hotels'),
    WishlistView.events => ('event', 'events'),
    WishlistView.estates => ('wine estate', 'wine estates'),
    WishlistView.trains => ('train', 'trains'),
    WishlistView.ships => ('ship', 'ships'),
    WishlistView.everything => ('item', 'items'),
  };
  return '$n ${n == 1 ? one : many}';
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    final t = (v ?? '').trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

class _GroupBuilder {
  final String title;
  String? country;
  final List<WishlistPlaceItem> items = [];
  _GroupBuilder(this.title);
}
