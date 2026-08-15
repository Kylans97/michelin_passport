import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../../models/visited_restaurant.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'photo_repository.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;

// public.visits is polymorphic (see production schema migration):
// entity_type + entity_id address either a hotel or a restaurant, with no
// foreign key on entity_id.
const _restaurantEntity = 'restaurant';
const _hotelEntity = 'hotel';

// Every column on public.visits (production schema v1 +
// 20260805211243_add_visit_details.sql +
// 20260814120000_social_foundation_step2_visit_visibility.sql). Listed
// explicitly, rather than select('*'), so a schema change is a visible
// diff here.
const _visitColumns =
    'id, user_id, entity_type, entity_id, visited_on, rating, '
    'food_rating, service_rating, wine_rating, value_rating, menu_type, '
    'notes, price_paid, currency, keys_at_visit, stars_at_visit, visibility';

class VisitedRepository {
  VisitedRepository(this._client);

  final SupabaseClient _client;

  // ── New polymorphic-schema API ──────────────────────────────────────────

  // All restaurant ids (entity_id) this user has a visit row for. A
  // restaurant can have more than one visit ("a second dinner is a second
  // row" — DATABASE_ARCHITECTURE.md section 4), so this is a set of
  // distinct ids, not a visit count.
  Future<Set<String>> loadVisitedRestaurantIds(String userId) async {
    final rows = await _client
        .from('visits')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity);
    return {for (final row in rows as List) row['entity_id'] as String};
  }

  Future<bool> isVisited(String userId, String restaurantId) async {
    final rows = await _client
        .from('visits')
        .select('id')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .eq('entity_id', restaurantId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  // Inserts a new visit row and returns the row Supabase actually created —
  // never guessed at afterward by querying "the latest visit". Supports
  // every column on public.visits: the overall `rating` plus the optional
  // food/service/wine/value sub-ratings and `menu_type` added in
  // 20260805211243_add_visit_details.sql, and notes, price_paid, currency,
  // keys_at_visit, stars_at_visit. Each visit is its own row; calling this
  // again for the same restaurant records a second, independent visit by
  // design. The returned Visit.id is what staged photos are then uploaded
  // against (see AddVisitSheet — a photo can't safely reference a visit
  // that doesn't exist in the database yet).
  Future<Visit> markVisited({
    required String userId,
    required String restaurantId,
    DateTime? visitedOn,
    int? rating,
    int? foodRating,
    int? serviceRating,
    int? wineRating,
    int? valueRating,
    MenuType? menuType,
    String? notes,
    double? pricePaid,
    String? currency,
    int? keysAtVisit,
    int? starsAtVisit,
    VisitVisibility visibility = VisitVisibility.private,
  }) {
    return _insertVisit(
      userId: userId,
      entityType: _restaurantEntity,
      entityId: restaurantId,
      visitedOn: visitedOn,
      rating: rating,
      foodRating: foodRating,
      serviceRating: serviceRating,
      wineRating: wineRating,
      valueRating: valueRating,
      menuType: menuType,
      notes: notes,
      pricePaid: pricePaid,
      currency: currency,
      keysAtVisit: keysAtVisit,
      starsAtVisit: starsAtVisit,
      visibility: visibility,
    );
  }

  // Inserts a new hotel stay row (same public.visits table, entity_type =
  // 'hotel'). Only the columns that make sense for a hotel are exposed:
  // the overall `rating`, `service_rating`, `value_rating`, `notes`, and
  // `keys_at_visit` — the hotel's Michelin Keys frozen at the moment of the
  // stay, so a later change to the hotel's *current* Keys never rewrites
  // this historical row (see Hotel.michelinKeys / HotelDetailScreen, which
  // passes it in explicitly, same as markVisited's starsAtVisit).
  // food_rating, wine_rating and menu_type are restaurant concepts and are
  // never set here — they stay NULL on every hotel stay row.
  // stars_at_visit is likewise never used for hotels; Michelin Stars are a
  // restaurant award. Returns the row Supabase actually created, same
  // reasoning as markVisited above.
  Future<Visit> markHotelStay({
    required String userId,
    required String hotelId,
    DateTime? visitedOn,
    int? rating,
    int? serviceRating,
    int? valueRating,
    String? notes,
    int? keysAtVisit,
    VisitVisibility visibility = VisitVisibility.private,
  }) {
    return _insertVisit(
      userId: userId,
      entityType: _hotelEntity,
      entityId: hotelId,
      visitedOn: visitedOn,
      rating: rating,
      serviceRating: serviceRating,
      valueRating: valueRating,
      notes: notes,
      keysAtVisit: keysAtVisit,
      visibility: visibility,
    );
  }

  // Shared insert behind markVisited and markHotelStay — a restaurant visit
  // and a hotel stay differ only in which columns the caller populates and
  // which entity_type/entity_id the row is written under. Uses
  // insert().select().single() to get the created row back directly from
  // Postgres, rather than a second "load the latest visit" query that
  // could race with another insert.
  Future<Visit> _insertVisit({
    required String userId,
    required String entityType,
    required String entityId,
    DateTime? visitedOn,
    int? rating,
    int? foodRating,
    int? serviceRating,
    int? wineRating,
    int? valueRating,
    MenuType? menuType,
    String? notes,
    double? pricePaid,
    String? currency,
    int? keysAtVisit,
    int? starsAtVisit,
    VisitVisibility visibility = VisitVisibility.private,
  }) async {
    final date = (visitedOn ?? DateTime.now()).toIso8601String().substring(
      0,
      10,
    );
    final row = await _client
        .from('visits')
        .insert({
          'user_id': userId,
          'entity_type': entityType,
          'entity_id': entityId,
          'visited_on': date,
          'rating': ?rating,
          'food_rating': ?foodRating,
          'service_rating': ?serviceRating,
          'wine_rating': ?wineRating,
          'value_rating': ?valueRating,
          'menu_type': ?menuType?.dbValue,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'price_paid': ?pricePaid,
          'currency': ?currency,
          'keys_at_visit': ?keysAtVisit,
          'stars_at_visit': ?starsAtVisit,
          'visibility': visibility.dbValue,
        })
        .select(_visitColumns)
        .single();
    return Visit.fromJson(row);
  }

  // Social Foundation Step 2 — the smallest sensible privacy-management
  // seam: this app has no general visit-edit flow (create + delete only),
  // so this is a single-column update, not a new edit architecture.
  // Scoped by both id and user_id, matching every other owner-write
  // method on this repository — belt-and-suspenders alongside RLS
  // (visits_update), which is the actual security boundary. Returns the
  // updated Visit so the caller can refresh its UI from the row Postgres
  // actually now holds, not an assumed value.
  Future<Visit> updateVisitVisibility({
    required String userId,
    required String visitId,
    required VisitVisibility visibility,
  }) async {
    final row = await _client
        .from('visits')
        .update({'visibility': visibility.dbValue})
        .eq('id', visitId)
        .eq('user_id', userId)
        .select(_visitColumns)
        .single();
    return Visit.fromJson(row);
  }

  // Deletes exactly one visit/stay row — never any other visit/stay to the
  // same restaurant/hotel. Constrained by both id and user_id (never
  // entity_id alone), per the product rule that one visit/stay is one
  // independent historical record.
  //
  // Deletes this visit's photos first (both storage objects and rows) via
  // PhotoRepository.deleteAllPhotosForVisit — photos.visit_id has no `on
  // delete cascade` (confirmed against the production schema), so the
  // visits row could never be deleted while photo rows still reference
  // it. If that photo cleanup's required row-delete step fails, this
  // throws before ever touching the visits table, leaving both the visit
  // and its photos intact rather than a partially-deleted state.
  Future<void> deleteVisitById({
    required String userId,
    required String visitId,
  }) async {
    await PhotoRepository(
      _client,
    ).deleteAllPhotosForVisit(userId: userId, visitId: visitId);
    await _client
        .from('visits')
        .delete()
        .eq('id', visitId)
        .eq('user_id', userId);
  }

  // Every visit this user has logged for one restaurant, newest first (by
  // visited_on desc). Repeat visits are never merged: a restaurant visited
  // three times returns three distinct rows, each independently viewable —
  // this is the foundation for Visit History / Visit Detail.
  Future<List<Visit>> loadVisitsForRestaurant(
    String userId,
    String restaurantId,
  ) => _loadVisitsForEntity(userId, _restaurantEntity, restaurantId);

  // Every stay this user has logged for one hotel, newest first. Repeat
  // stays are never merged — same guarantee as loadVisitsForRestaurant,
  // and the foundation for Hotel Detail's stay history / Stay Detail.
  Future<List<Visit>> loadStaysForHotel(String userId, String hotelId) =>
      _loadVisitsForEntity(userId, _hotelEntity, hotelId);

  Future<List<Visit>> _loadVisitsForEntity(
    String userId,
    String entityType,
    String entityId,
  ) async {
    final rows = await _client
        .from('visits')
        .select(_visitColumns)
        .eq('user_id', userId)
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('visited_on', ascending: false);
    return (rows as List)
        .map((row) => Visit.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // A single visit by id, or null if it doesn't exist (or isn't visible to
  // the caller under RLS). Not yet wired into any screen — the Visit Detail
  // screen is currently navigated to with the Visit already in hand from
  // [loadVisitsForRestaurant] — but kept available for later deep-linking.
  Future<Visit?> loadVisitById(String visitId) async {
    final rows = await _client
        .from('visits')
        .select(_visitColumns)
        .eq('id', visitId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Visit.fromJson(list.first as Map<String, dynamic>);
  }

  // Every venue (restaurant or hotel) this user has visited/stayed at,
  // each paired with every visit/stay logged against it (newest first) —
  // one entry per unique venue. This is the data My Passport (All /
  // Restaurants / Hotels) is built from.
  //
  // entity_type is not filtered here — the visits check constraint only
  // ever allows 'restaurant' or 'hotel', so every row of this user's
  // belongs to one or the other. Three queries total, regardless of how
  // many visits/stays exist: one for all visit rows, one batched
  // restaurants_full lookup, one batched hotels_full lookup — never one
  // query per venue.
  Future<List<VenueEntry>> loadPassportVenues(String userId) async {
    final rows = await _client
        .from('visits')
        .select(_visitColumns)
        .eq('user_id', userId)
        .order('visited_on', ascending: false);
    final visitRows = (rows as List).cast<Map<String, dynamic>>();
    if (visitRows.isEmpty) return [];

    // Insertion order follows the visited_on-desc query order, so each
    // venue's own visit list comes out newest-first for free.
    final restaurantVisitsById = <String, List<Visit>>{};
    final hotelVisitsById = <String, List<Visit>>{};
    for (final row in visitRows) {
      final visit = Visit.fromJson(row);
      final byId = visit.entityType == _hotelEntity
          ? hotelVisitsById
          : restaurantVisitsById;
      byId.putIfAbsent(visit.entityId, () => []).add(visit);
    }

    final restaurantsByIdFuture = _resolveRestaurantsByIds(
      restaurantVisitsById.keys,
    );
    final hotelsByIdFuture = _resolveHotelsByIds(hotelVisitsById.keys);
    final restaurantsById = await restaurantsByIdFuture;
    final hotelsById = await hotelsByIdFuture;

    return [
      for (final entry in restaurantVisitsById.entries)
        if (restaurantsById[entry.key] != null)
          VenueEntry(
            venue: RestaurantVenue(restaurantsById[entry.key]!),
            visits: entry.value,
          ),
      for (final entry in hotelVisitsById.entries)
        if (hotelsById[entry.key] != null)
          VenueEntry(
            venue: HotelVenue(hotelsById[entry.key]!),
            visits: entry.value,
          ),
    ];
  }

  Future<Map<String, Hotel>> _resolveHotelsByIds(Iterable<String> ids) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return {};
    final rows = await _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .inFilter('id', idList);
    return {
      for (final row in rows as List)
        (row['id'] as String): Hotel.fromJson(row as Map<String, dynamic>),
    };
  }

  // ── Existing API, kept working against the new schema ──────────────────
  // restaurants_full cannot be embedded via a foreign-key join from visits
  // (entity_id is deliberately not a foreign key — see
  // DATABASE_ARCHITECTURE.md section 4), so these resolve restaurant rows
  // in a second query instead of a single embedded select.

  // Returns all restaurants the user has visited, most recently visited
  // first. A restaurant visited more than once appears once, at its most
  // recent visit date.
  Future<List<Restaurant>> getVisited(String userId) async {
    final visitRows = await _fetchRestaurantVisitRows(userId);
    if (visitRows.isEmpty) return [];

    final restaurantsById = await _resolveRestaurantsByIds(
      visitRows.map((row) => row['entity_id'] as String),
    );
    final seen = <String>{};
    final result = <Restaurant>[];
    for (final row in visitRows) {
      final id = row['entity_id'] as String;
      final restaurant = restaurantsById[id];
      if (restaurant != null && seen.add(id)) result.add(restaurant);
    }
    return result;
  }

  // Returns one entry per visit (not deduplicated) with its rating, notes
  // and date, most recently visited first.
  Future<List<VisitedRestaurant>> getVisitedWithRatings(String userId) async {
    final visitRows = await _fetchRestaurantVisitRows(userId);
    if (visitRows.isEmpty) return [];

    final restaurantsById = await _resolveRestaurantsByIds(
      visitRows.map((row) => row['entity_id'] as String),
    );
    return [
      for (final row in visitRows)
        if (restaurantsById[row['entity_id'] as String] != null)
          VisitedRestaurant(
            restaurant: restaurantsById[row['entity_id'] as String]!,
            personalRating: (row['rating'] as num?)?.toDouble(),
            notes: row['notes'] as String?,
            visitedAt: DateTime.tryParse(row['visited_on'] as String),
          ),
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchRestaurantVisitRows(
    String userId,
  ) async {
    final rows = await _client
        .from('visits')
        .select('entity_id, rating, notes, visited_on')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .order('visited_on', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, Restaurant>> _resolveRestaurantsByIds(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return {};
    final rows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', idList);
    return {
      for (final row in rows as List)
        (row['id'] as String): Restaurant.fromJson(row as Map<String, dynamic>),
    };
  }
}
