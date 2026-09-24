import '../../models/passport_venue.dart';
import '../../models/profile_identity.dart';
import '../../models/venue_entry.dart';
import 'friend_profile_screen.dart' show FriendVenueVisit;

/// City name for [FriendVenueVisit.venue] — [PassportVenue] itself only
/// exposes [PassportVenue.countryCode] at the base-type level, not city
/// (Restaurant/Hotel each carry their own `cityName`).
extension FriendProfileVisitDisplay on FriendVenueVisit {
  String get cityName => switch (venue) {
    RestaurantVenue(:final restaurant) => restaurant.cityName,
    HotelVenue(:final hotel) => hotel.cityName,
  };

  bool get isHotel => venue is HotelVenue;

  /// Stars AT THIS VISIT for a restaurant; null for a hotel stay (use
  /// [keys] instead) — same "frozen at the moment of the visit" reasoning
  /// Passport's own stamps already established, not the venue's current
  /// award.
  int? get stars => switch (venue) {
    RestaurantVenue() => visit.starsAtVisit,
    HotelVenue() => null,
  };

  /// Keys AT THIS STAY for a hotel; null for a restaurant visit.
  int? get keys => switch (venue) {
    RestaurantVenue() => null,
    HotelVenue() => visit.keysAtVisit,
  };

  /// 1–10, or null if this visit wasn't rated. Shown as the stamps' own
  /// "score" (e.g. "8/10") — this screen's own addition; the main
  /// Passport stamps don't show a score.
  int? get score => visit.rating;
}

/// The friend-profile's stats — the Passport tab's own "Stamps /
/// Countries / Avg. score" row, plus [totalStars] for the header's
/// `@HANDLE · N STAMPS · N STARS` line (a different metric: a simple
/// Michelin-star count, not a 1–10 rating average).
///
/// - [stamps] = total VISITS (restaurant + hotel), matching this screen's
///   "one stamp per visit" model (see [FriendVenueVisit] itself) — not
///   deduplicated per venue.
/// - [countries] = unique country codes across every visited venue.
/// - [avgScore] = the arithmetic mean of every RATED visit's score (both
///   restaurant and hotel — an average naturally treats every visit as
///   one data point regardless of type). Null when nothing has been
///   rated — never coerced to 0, matching this app's established "never
///   invent a rating" rule elsewhere (see PassportVenueStats
///   .averageRating).
/// - [totalStars] = the same rule the main Passport's own stats row uses
///   (see `PassportVenueStats.awardAtLatestVisit`): each unique
///   RESTAURANT venue's stars at its most recent visit, summed once per
///   venue, never once per visit. Restricted to restaurants — a hotel's
///   Keys are a different award.
class FriendProfileStats {
  final int stamps;
  final int countries;
  final double? avgScore;
  final int totalStars;

  const FriendProfileStats({
    required this.stamps,
    required this.countries,
    required this.avgScore,
    required this.totalStars,
  });

  factory FriendProfileStats.from(List<VenueEntry> entries) {
    var stamps = 0;
    final countries = <String>{};
    final scores = <int>[];
    var starSum = 0;

    for (final entry in entries) {
      if (entry.visits.isEmpty) continue;
      stamps += entry.visits.length;
      countries.add(entry.venue.countryCode);
      for (final visit in entry.visits) {
        if (visit.rating != null) scores.add(visit.rating!);
      }
      if (entry.venue case RestaurantVenue()) {
        final latest = entry.visits.reduce(
          (a, b) => a.visitedOn.isAfter(b.visitedOn) ? a : b,
        );
        starSum += latest.starsAtVisit ?? 0;
      }
    }

    return FriendProfileStats(
      stamps: stamps,
      countries: countries.length,
      avgScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      totalStars: starSum,
    );
  }
}

/// A stable key identifying [venue] across both wishlists being compared —
/// a restaurant and a hotel never collide even if their ids happened to,
/// since the key is namespaced by venue type.
String wishlistVenueKey(PassportVenue venue) => switch (venue) {
  RestaurantVenue(:final restaurant) => 'r:${restaurant.id}',
  HotelVenue(:final hotel) => 'h:${hotel.id}',
};

/// Which of the friend's [wishlist] items are also on the viewer's own
/// [myWishlist] — the Overview "N in common" bar, the "YOU TOO"-style
/// surfacing, and the Together tab's shared/only-theirs split. Matched by
/// venue identity (see [wishlistVenueKey]), never by name (this app never
/// matches venues on name — see CLAUDE.md's own "Identity" rule).
Set<String> sharedWishlistKeys({
  required List<PassportVenue> wishlist,
  required List<PassportVenue> myWishlist,
}) {
  final mine = myWishlist.map(wishlistVenueKey).toSet();
  return {
    for (final venue in wishlist)
      if (mine.contains(wishlistVenueKey(venue))) wishlistVenueKey(venue),
  };
}

/// [visits]' own highest-rated entry (by [FriendVenueVisit.score]) — ties
/// and unrated visits fall back to the most recent one, so this always
/// returns something as long as [visits] isn't empty.
FriendVenueVisit? highestRatedVisit(List<FriendVenueVisit> visits) {
  if (visits.isEmpty) return null;
  final rated = visits.where((v) => v.score != null).toList();
  if (rated.isEmpty) return visits.first; // already newest-first
  rated.sort((a, b) {
    final byScore = b.score!.compareTo(a.score!);
    if (byScore != 0) return byScore;
    return b.visit.visitedOn.compareTo(a.visit.visitedOn);
  });
  return rated.first;
}

/// Everything the friend-profile screen's three tabs render from —
/// resolved once by [FriendProfileScreen] after every underlying future
/// completes, so a tab widget is pure presentation over already-shaped
/// data, not its own data-fetching state machine.
class FriendProfileLayoutData {
  final ProfileIdentity identity;
  final ProfileIdentity? myIdentity;
  final List<VenueEntry> visitedEntries;
  final List<FriendVenueVisit> visits;
  final List<PassportVenue> wishlist;
  final List<PassportVenue> myWishlist;
  final Set<String> sharedKeys;
  final FriendProfileStats stats;
  final Map<String, String> coverPhotoByVisitId;

  const FriendProfileLayoutData({
    required this.identity,
    required this.myIdentity,
    required this.visitedEntries,
    required this.visits,
    required this.wishlist,
    required this.myWishlist,
    required this.sharedKeys,
    required this.stats,
    required this.coverPhotoByVisitId,
  });

  String get friendName =>
      identity.displayName?.trim().isNotEmpty == true
      ? identity.displayName!
      : identity.label;

  /// The friend's wishlist items that are also on the viewer's own —
  /// Together tab section 1, Overview's "N in common" bar.
  List<PassportVenue> get sharedWishlistVenues =>
      wishlist.where((v) => sharedKeys.contains(wishlistVenueKey(v))).toList();

  /// The friend's wishlist items the viewer doesn't have — Together tab's
  /// "ONLY ON {NAME}'S LIST".
  List<PassportVenue> get onlyTheirWishlistVenues =>
      wishlist.where((v) => !sharedKeys.contains(wishlistVenueKey(v))).toList();
}
