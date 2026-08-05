import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/visit.dart';
import '../../models/visited_restaurant.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;

// public.visits is polymorphic (see production schema migration):
// entity_type + entity_id address either a hotel or a restaurant, with no
// foreign key on entity_id. This repository only ever writes and reads
// entity_type = 'restaurant' rows.
const _restaurantEntity = 'restaurant';

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

  // Inserts a new visit row. Supports every column on public.visits: the
  // overall `rating` plus the optional food/service/wine/value sub-ratings
  // and `menu_type` added in 20260805211243_add_visit_details.sql, and
  // notes, price_paid, currency, keys_at_visit, stars_at_visit. Each visit
  // is its own row; calling this again for the same restaurant records a
  // second, independent visit by design.
  Future<void> markVisited({
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
  }) async {
    final date = (visitedOn ?? DateTime.now()).toIso8601String().substring(
      0,
      10,
    );
    await _client.from('visits').insert({
      'user_id': userId,
      'entity_type': _restaurantEntity,
      'entity_id': restaurantId,
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
    });
  }

  // Clears every visit row for this restaurant, i.e. fully un-marks it as
  // visited. The current UI is a single visited/not-visited toggle, not a
  // per-visit list, so "remove" means "remove all" here — matches the
  // existing toggle behaviour rather than picking one row to delete.
  Future<void> removeVisit({
    required String userId,
    required String restaurantId,
  }) async {
    await _client
        .from('visits')
        .delete()
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .eq('entity_id', restaurantId);
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

    final restaurantsById = await _resolveRestaurants(visitRows);
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

    final restaurantsById = await _resolveRestaurants(visitRows);
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

  Future<Map<String, Restaurant>> _resolveRestaurants(
    List<Map<String, dynamic>> visitRows,
  ) async {
    final ids = {for (final row in visitRows) row['entity_id'] as String};
    final rows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', ids.toList());
    return {
      for (final row in rows as List)
        (row['id'] as String): Restaurant.fromJson(row as Map<String, dynamic>),
    };
  }
}
