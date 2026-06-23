import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';

class WishlistRepository {
  WishlistRepository(this._client);

  final SupabaseClient _client;

  // Returns the user's wishlist ordered by when each item was added.
  Future<List<Restaurant>> getWishlist(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('added_at, restaurants(*)')
        .eq('user_id', userId)
        .order('added_at', ascending: false);

    return (rows as List).map((row) {
      final restaurantJson = row['restaurants'] as Map<String, dynamic>;
      return Restaurant.fromJson(restaurantJson);
    }).toList();
  }

  // Adds a restaurant to the wishlist.  Ignores duplicates (UNIQUE constraint).
  Future<void> add({
    required String userId,
    required String restaurantId,
  }) async {
    try {
      await _client.from('wishlist').insert({
        'user_id': userId,
        'restaurant_id': restaurantId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  // Removes a restaurant from the wishlist.
  Future<void> remove({
    required String userId,
    required String restaurantId,
  }) async {
    await _client
        .from('wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId);
  }

  // Returns true when the restaurant is already in the user's wishlist.
  Future<bool> isWishlisted({
    required String userId,
    required String restaurantId,
  }) async {
    final rows = await _client
        .from('wishlist')
        .select('id')
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}
