import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/visited_restaurant.dart';

class VisitedRepository {
  VisitedRepository(this._client);

  final SupabaseClient _client;

  // Returns all restaurants the authenticated user has visited, most recent first.
  Future<List<Restaurant>> getVisited(String userId) async {
    final rows = await _client
        .from('visited_restaurants')
        .select('visited_at, restaurants(*)')
        .eq('user_id', userId)
        .order('visited_at', ascending: false);

    return (rows as List).map((row) {
      final restaurantJson = row['restaurants'] as Map<String, dynamic>;
      return Restaurant.fromJson(restaurantJson);
    }).toList();
  }

  // Returns visited restaurants with personal_rating, notes, and visitedAt included.
  Future<List<VisitedRestaurant>> getVisitedWithRatings(String userId) async {
    final rows = await _client
        .from('visited_restaurants')
        .select('visited_at, personal_rating, notes, restaurants(*)')
        .eq('user_id', userId)
        .order('personal_rating', ascending: false, nullsFirst: false);

    return (rows as List).map((row) {
      final restaurantJson = row['restaurants'] as Map<String, dynamic>;
      return VisitedRestaurant(
        restaurant: Restaurant.fromJson(restaurantJson),
        personalRating: (row['personal_rating'] as num?)?.toDouble(),
        notes: row['notes'] as String?,
        visitedAt: row['visited_at'] != null
            ? DateTime.tryParse(row['visited_at'] as String)
            : null,
      );
    }).toList();
  }

  // Marks a restaurant as visited with an optional personal rating and notes.
  Future<void> addVisit({
    required String userId,
    required String restaurantId,
    double? personalRating,
    String? notes,
  }) async {
    try {
      await _client.from('visited_restaurants').insert({
        'user_id': userId,
        'restaurant_id': restaurantId,
        'personal_rating': ?personalRating,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — already visited, fine to ignore
      if (e.code != '23505') rethrow;
    }
  }

  // Updates the personal rating (and optionally notes) for an existing visit.
  Future<void> updateRating({
    required String userId,
    required String restaurantId,
    double? personalRating,
    String? notes,
  }) async {
    await _client
        .from('visited_restaurants')
        .update({
          'personal_rating': ?personalRating,
          'notes': ?notes,
        })
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId);
  }

  // Removes a visit stamp.
  Future<void> removeVisit({
    required String userId,
    required String restaurantId,
  }) async {
    await _client
        .from('visited_restaurants')
        .delete()
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId);
  }

  // Returns true if the user has already visited this restaurant.
  Future<bool> hasVisited({
    required String userId,
    required String restaurantId,
  }) async {
    final rows = await _client
        .from('visited_restaurants')
        .select('restaurant_id')
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}
