import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;

// public.wishlist is polymorphic, same shape as public.visits: entity_type +
// entity_id, no foreign key on entity_id. This repository only ever writes
// and reads entity_type = 'restaurant' rows.
const _restaurantEntity = 'restaurant';

class WishlistRepository {
  WishlistRepository(this._client);

  final SupabaseClient _client;

  // ── New polymorphic-schema API ──────────────────────────────────────────

  Future<Set<String>> loadWishlistRestaurantIds(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity);
    return {for (final row in rows as List) row['entity_id'] as String};
  }

  // Flips wishlist membership and returns the new state (true = now
  // wishlisted). UNIQUE (user_id, entity_type, entity_id) on the table
  // makes the insert path safe to retry.
  Future<bool> toggleWishlist({
    required String userId,
    required String restaurantId,
  }) async {
    final alreadyIn = await isWishlisted(
      userId: userId,
      restaurantId: restaurantId,
    );
    if (alreadyIn) {
      await remove(userId: userId, restaurantId: restaurantId);
      return false;
    }
    await add(userId: userId, restaurantId: restaurantId);
    return true;
  }

  // ── Existing API, kept working against the new schema ──────────────────

  Future<bool> isWishlisted({
    required String userId,
    required String restaurantId,
  }) async {
    final rows = await _client
        .from('wishlist')
        .select('user_id')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .eq('entity_id', restaurantId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> add({
    required String userId,
    required String restaurantId,
  }) async {
    try {
      await _client.from('wishlist').insert({
        'user_id': userId,
        'entity_type': _restaurantEntity,
        'entity_id': restaurantId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — already wishlisted, fine to ignore
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> remove({
    required String userId,
    required String restaurantId,
  }) async {
    await _client
        .from('wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .eq('entity_id', restaurantId);
  }

  // restaurants_full cannot be embedded via a foreign-key join from
  // wishlist (entity_id is deliberately not a foreign key — see
  // DATABASE_ARCHITECTURE.md section 4), so this resolves restaurant rows
  // in a second query instead of a single embedded select.
  Future<List<Restaurant>> getWishlist(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', _restaurantEntity)
        .order('added_at', ascending: false);
    final ids = [for (final row in rows as List) row['entity_id'] as String];
    if (ids.isEmpty) return [];

    final restaurantRows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', ids);
    final byId = {
      for (final row in restaurantRows as List)
        (row['id'] as String): Restaurant.fromJson(row as Map<String, dynamic>),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }
}
