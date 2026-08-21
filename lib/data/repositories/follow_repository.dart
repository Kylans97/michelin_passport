import 'package:supabase_flutter/supabase_flutter.dart';

/// Events V2 Step 6 UX correction — the success-feedback snackbar text
/// shown after a Follow/Unfollow write actually succeeds. A pure,
/// top-level function (no `this`, no Supabase) specifically so the exact
/// wording is unit-testable without pumping any of the three
/// Supabase-eager Detail screens that call it — Restaurant, Hotel, and
/// Private Chef all share this single implementation rather than each
/// re-deriving the same "Following X" / "Unfollowed X" ternary inline, so
/// the three screens can never drift apart on phrasing.
String followSnackMessage({
  required bool wasFollowing,
  required String entityName,
}) => wasFollowing ? 'Unfollowed $entityName' : 'Following $entityName';

// public.follows_restaurants / follows_hotels / follows_private_chefs —
// Events V2 Step 1 database foundation (dedicated typed tables, not a
// polymorphic `follows`; see EVENTS_V2_ARCHITECTURE.md §15.2), unused by
// any Dart code before Step 6. Each table: id, user_id, <entity>_id,
// created_at, unique(user_id, <entity>_id), owner-only RLS
// (follows_*_select/_insert/_delete — no UPDATE policy exists, since a
// follow row has nothing mutable; existence is the entire signal).
const _restaurantsTable = 'follows_restaurants';
const _hotelsTable = 'follows_hotels';
const _privateChefsTable = 'follows_private_chefs';

const _restaurantColumn = 'restaurant_id';
const _hotelColumn = 'hotel_id';
const _privateChefColumn = 'private_chef_id';

/// Reads/writes the three dedicated `follows_*` tables. One type-safe
/// repository with named per-entity methods, not three near-duplicate
/// classes and not a raw-string generic API — the three tables are
/// structurally identical (same columns, same constraints, same RLS
/// shape), so per-type classes would just copy-paste the same logic three
/// times; named methods keep every call site type-safe without ever
/// exposing a bare entity-type string to screen code (mirrors
/// [WishlistRepository]'s own established `toggleWishlist`/
/// `toggleHotelWishlist` shape exactly — no shared "entity type" parameter
/// leaks out of that repository either, only its own private
/// implementation dispatches on one internally).
///
/// RLS (`follows_*_select`/`_insert`/`_delete`, all `user_id = auth.uid()`)
/// is the actual security boundary throughout — every read here returns
/// only what the database already decided the caller may see, and every
/// write is scoped to the caller's own `user_id` regardless of what this
/// class sends. No count query, no follower-list query, no service-role
/// bypass exists anywhere in this class — Follow stays a private,
/// owner-only personalization signal (Events V2 Step 6 Follow Audit §8).
class FollowRepository {
  FollowRepository(this._client);

  final SupabaseClient _client;

  // ── Restaurant ───────────────────────────────────────────────────────

  Future<bool> isFollowingRestaurant({
    required String userId,
    required String restaurantId,
  }) => _isFollowing(
    table: _restaurantsTable,
    userId: userId,
    entityColumn: _restaurantColumn,
    entityId: restaurantId,
  );

  Future<void> followRestaurant({
    required String userId,
    required String restaurantId,
  }) => _follow(
    table: _restaurantsTable,
    userId: userId,
    entityColumn: _restaurantColumn,
    entityId: restaurantId,
  );

  Future<void> unfollowRestaurant({
    required String userId,
    required String restaurantId,
  }) => _unfollow(
    table: _restaurantsTable,
    userId: userId,
    entityColumn: _restaurantColumn,
    entityId: restaurantId,
  );

  // ── Hotel ────────────────────────────────────────────────────────────

  Future<bool> isFollowingHotel({
    required String userId,
    required String hotelId,
  }) => _isFollowing(
    table: _hotelsTable,
    userId: userId,
    entityColumn: _hotelColumn,
    entityId: hotelId,
  );

  Future<void> followHotel({required String userId, required String hotelId}) =>
      _follow(
        table: _hotelsTable,
        userId: userId,
        entityColumn: _hotelColumn,
        entityId: hotelId,
      );

  Future<void> unfollowHotel({
    required String userId,
    required String hotelId,
  }) => _unfollow(
    table: _hotelsTable,
    userId: userId,
    entityColumn: _hotelColumn,
    entityId: hotelId,
  );

  // ── Private Chef ─────────────────────────────────────────────────────

  Future<bool> isFollowingPrivateChef({
    required String userId,
    required String privateChefId,
  }) => _isFollowing(
    table: _privateChefsTable,
    userId: userId,
    entityColumn: _privateChefColumn,
    entityId: privateChefId,
  );

  Future<void> followPrivateChef({
    required String userId,
    required String privateChefId,
  }) => _follow(
    table: _privateChefsTable,
    userId: userId,
    entityColumn: _privateChefColumn,
    entityId: privateChefId,
  );

  Future<void> unfollowPrivateChef({
    required String userId,
    required String privateChefId,
  }) => _unfollow(
    table: _privateChefsTable,
    userId: userId,
    entityColumn: _privateChefColumn,
    entityId: privateChefId,
  );

  // ── Shared implementation — identical shape across all three tables ────

  Future<bool> _isFollowing({
    required String table,
    required String userId,
    required String entityColumn,
    required String entityId,
  }) async {
    final rows = await _client
        .from(table)
        .select('id')
        .eq('user_id', userId)
        .eq(entityColumn, entityId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  // Idempotent: a duplicate insert (already following) hits the unique
  // (user_id, <entity>_id) constraint as a 23505 violation, swallowed here
  // — same convention as WishlistRepository._add /
  // EventConfirmedAttendanceRepository.confirmAttendance. The caller
  // already checked/knows the intended end state; a race that lands here
  // twice must never surface as an error for what is, from the user's
  // perspective, already true.
  Future<void> _follow({
    required String table,
    required String userId,
    required String entityColumn,
    required String entityId,
  }) async {
    try {
      await _client.from(table).insert({
        'user_id': userId,
        entityColumn: entityId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  // Scoped by both user_id and the entity column — belt-and-suspenders
  // alongside RLS (follows_*_delete is already owner-only), matching
  // every other owner-write method in this codebase. Deleting an
  // already-absent row is a no-op, same as WishlistRepository._remove.
  Future<void> _unfollow({
    required String table,
    required String userId,
    required String entityColumn,
    required String entityId,
  }) async {
    await _client
        .from(table)
        .delete()
        .eq('user_id', userId)
        .eq(entityColumn, entityId);
  }
}
