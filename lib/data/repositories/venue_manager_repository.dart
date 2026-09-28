import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/managed_venue.dart';
import '../../models/private_chef.dart';
import '../../models/restaurant.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'private_chef_repository.dart' show privateChefFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;

/// Reads venue_managers_restaurants/_hotels/_private_chefs — the CURRENT
/// state of who manages what — never claims_restaurants/claims_hotels/
/// claims_private_chefs, which are a historical request and were never
/// meant to answer "what can this user do right now" (see
/// 20260930120000_add_venue_managers_permission_tables.sql and
/// 20261001120000_venue_managers_cutover.sql for the full reasoning).
/// RLS on all three tables is read-own-rows-only with no client insert/
/// update/delete path at all — this repository is read-only by
/// construction, matching that; there is no write method here and none
/// are planned (granting/revoking stays a service_role/dashboard action,
/// see docs/Engineering/VENUE_CLAIM_OPERATIONS.md).
class VenueManagerRepository {
  VenueManagerRepository(this._client);

  final SupabaseClient _client;

  /// Every venue the signed-in user actively manages (revoked_at is
  /// null), across all three types, name-sorted. Mirrors
  /// WishlistRepository.loadWishlistVenues()'s own shape exactly: one
  /// query per venue_managers_* table for the ids, then one batched
  /// *_full lookup per venue type (never one query per venue) — six
  /// queries total regardless of how many venues are managed. A venue
  /// that couldn't be resolved (e.g. delisted) is skipped rather than
  /// crashing, same as that method's own established handling.
  Future<List<ManagedVenue>> loadMyManagedVenues() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final grantRows = await Future.wait([
      _client
          .from('venue_managers_restaurants')
          .select('restaurant_id')
          .eq('user_id', userId)
          .isFilter('revoked_at', null),
      _client
          .from('venue_managers_hotels')
          .select('hotel_id')
          .eq('user_id', userId)
          .isFilter('revoked_at', null),
      _client
          .from('venue_managers_private_chefs')
          .select('private_chef_id')
          .eq('user_id', userId)
          .isFilter('revoked_at', null),
    ]);

    final restaurantIds = [
      for (final row in grantRows[0]) row['restaurant_id'] as String,
    ];
    final hotelIds = [for (final row in grantRows[1]) row['hotel_id'] as String];
    final chefIds = [
      for (final row in grantRows[2]) row['private_chef_id'] as String,
    ];

    if (restaurantIds.isEmpty && hotelIds.isEmpty && chefIds.isEmpty) return [];

    final restaurantsFuture = restaurantIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _client
              .from('restaurants_full')
              .select(restaurantFullColumns)
              .inFilter('id', restaurantIds)
              .then((r) => (r as List).cast<Map<String, dynamic>>());
    final hotelsFuture = hotelIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _client
              .from('hotels_full')
              .select(hotelFullColumns)
              .inFilter('id', hotelIds)
              .then((r) => (r as List).cast<Map<String, dynamic>>());
    final chefsFuture = chefIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _client
              .from('private_chefs_full')
              .select(privateChefFullColumns)
              .inFilter('id', chefIds)
              .then((r) => (r as List).cast<Map<String, dynamic>>());

    final restaurantRows = await restaurantsFuture;
    final hotelRows = await hotelsFuture;
    final chefRows = await chefsFuture;

    final venues = <ManagedVenue>[
      for (final row in restaurantRows) ManagedRestaurant(Restaurant.fromJson(row)),
      for (final row in hotelRows) ManagedHotel(Hotel.fromJson(row)),
      for (final row in chefRows) ManagedPrivateChef(PrivateChef.fromJson(row)),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return venues;
  }
}
