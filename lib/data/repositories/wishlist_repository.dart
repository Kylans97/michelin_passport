import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import 'events_repository.dart' show EventsRepository;
import 'hotel_repository.dart' show hotelFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;

// public.wishlist is polymorphic, same shape as public.visits: entity_type +
// entity_id, no foreign key on entity_id. EVENT WISHLIST V1 adds 'event' as
// a third entity_type — see
// supabase/migrations/20260825150000_add_event_wishlist.sql (widens the
// existing entity_type CHECK constraint; no new table, same unique
// (user_id, entity_type, entity_id) constraint, same RLS policies —
// nothing keyed on entity_type there).
const _restaurantEntity = 'restaurant';
const _hotelEntity = 'hotel';
const _eventEntity = 'event';

class WishlistRepository {
  WishlistRepository(this._client);

  final SupabaseClient _client;

  // ── Restaurant API (unchanged — existing call sites keep working) ──────

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
  }) => _toggle(
    userId: userId,
    entityType: _restaurantEntity,
    entityId: restaurantId,
  );

  Future<bool> isWishlisted({
    required String userId,
    required String restaurantId,
  }) => _isWishlisted(
    userId: userId,
    entityType: _restaurantEntity,
    entityId: restaurantId,
  );

  Future<void> add({required String userId, required String restaurantId}) =>
      _add(
        userId: userId,
        entityType: _restaurantEntity,
        entityId: restaurantId,
      );

  Future<void> remove({required String userId, required String restaurantId}) =>
      _remove(
        userId: userId,
        entityType: _restaurantEntity,
        entityId: restaurantId,
      );

  // restaurants_full cannot be embedded via a foreign-key join from
  // wishlist (entity_id is deliberately not a foreign key — see
  // DATABASE_ARCHITECTURE.md section 4), so this resolves restaurant rows
  // in a second query instead of a single embedded select.
  Future<List<Restaurant>> getWishlist(String userId) async {
    final ids = await _wishlistedIds(userId, _restaurantEntity);
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

  // ── Hotel API — mirrors the restaurant one exactly ──────────────────────

  // Passport UI Polish V2 — mirrors loadWishlistRestaurantIds exactly, for
  // the same bulk-membership-check use case (Passport's collection cards
  // need "is this hotel wishlisted" for many hotels at once, never one
  // isHotelWishlisted call per card).
  Future<Set<String>> loadWishlistHotelIds(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', _hotelEntity);
    return {for (final row in rows as List) row['entity_id'] as String};
  }

  Future<bool> toggleHotelWishlist({
    required String userId,
    required String hotelId,
  }) => _toggle(userId: userId, entityType: _hotelEntity, entityId: hotelId);

  Future<bool> isHotelWishlisted({
    required String userId,
    required String hotelId,
  }) => _isWishlisted(
    userId: userId,
    entityType: _hotelEntity,
    entityId: hotelId,
  );

  Future<void> addHotel({required String userId, required String hotelId}) =>
      _add(userId: userId, entityType: _hotelEntity, entityId: hotelId);

  Future<void> removeHotel({required String userId, required String hotelId}) =>
      _remove(userId: userId, entityType: _hotelEntity, entityId: hotelId);

  // ── Event API (EVENT WISHLIST V1) — mirrors the restaurant/hotel ones
  // exactly, same shape, same _toggle/_isWishlisted/_add/_remove shared
  // implementation. Wishlist = canonical individual Event id only (see
  // this feature's own migration header comment) — no event-series/
  // recurring-identity concept, deliberately out of scope for V1.

  Future<Set<String>> loadWishlistEventIds(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', _eventEntity);
    return {for (final row in rows as List) row['entity_id'] as String};
  }

  Future<bool> toggleEventWishlist({
    required String userId,
    required String eventId,
  }) => _toggle(userId: userId, entityType: _eventEntity, entityId: eventId);

  Future<bool> isEventWishlisted({
    required String userId,
    required String eventId,
  }) => _isWishlisted(
    userId: userId,
    entityType: _eventEntity,
    entityId: eventId,
  );

  Future<void> addEvent({required String userId, required String eventId}) =>
      _add(userId: userId, entityType: _eventEntity, entityId: eventId);

  Future<void> removeEvent({required String userId, required String eventId}) =>
      _remove(userId: userId, entityType: _eventEntity, entityId: eventId);

  // Every wishlisted Event, added_at-desc, resolved against the canonical
  // `events` table via EventsRepository.loadEventsByIds — one batched
  // lookup regardless of wishlist size, matching [getWishlist]'s own
  // "resolve real rows, skip whatever no longer exists" shape. An Event
  // later unpublished/archived/deleted simply drops out of this list —
  // never a crash, never an orphaned entry surfaced to the UI (see the
  // migration's own doc comment on this).
  Future<List<Event>> getWishlistEvents(String userId) async {
    final ids = await _wishlistedIds(userId, _eventEntity);
    if (ids.isEmpty) return [];
    final events = await EventsRepository(_client).loadEventsByIds(ids);
    final byId = {for (final event in events) event.id: event};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // ── Combined All/Restaurants/Hotels wishlist ────────────────────────────

  // Every wishlisted venue (both types), newest-first, resolved as
  // PassportVenue so the Wishlist screen can reuse the same sealed
  // restaurant/hotel abstraction My Passport already uses. Three queries
  // total regardless of wishlist size — one for the wishlist rows, one
  // batched restaurants_full lookup, one batched hotels_full lookup — never
  // one query per venue.
  Future<List<PassportVenue>> loadWishlistVenues(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_type, entity_id')
        .eq('user_id', userId)
        .order('added_at', ascending: false);
    final wishlistRows = (rows as List).cast<Map<String, dynamic>>();
    if (wishlistRows.isEmpty) return [];

    final restaurantIds = [
      for (final row in wishlistRows)
        if (row['entity_type'] == _restaurantEntity) row['entity_id'] as String,
    ];
    final hotelIds = [
      for (final row in wishlistRows)
        if (row['entity_type'] == _hotelEntity) row['entity_id'] as String,
    ];

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

    final restaurantRows = await restaurantsFuture;
    final hotelRows = await hotelsFuture;

    final restaurantsById = {
      for (final row in restaurantRows)
        (row['id'] as String): Restaurant.fromJson(row),
    };
    final hotelsById = {
      for (final row in hotelRows) (row['id'] as String): Hotel.fromJson(row),
    };

    // Preserves the wishlist's own added_at-desc order, skipping any row
    // whose venue couldn't be resolved (e.g. delisted) rather than
    // crashing on a null.
    final venues = <PassportVenue>[];
    for (final row in wishlistRows) {
      final entityId = row['entity_id'] as String;
      if (row['entity_type'] == _restaurantEntity) {
        final restaurant = restaurantsById[entityId];
        if (restaurant != null) venues.add(RestaurantVenue(restaurant));
      } else if (row['entity_type'] == _hotelEntity) {
        final hotel = hotelsById[entityId];
        if (hotel != null) venues.add(HotelVenue(hotel));
      }
    }
    return venues;
  }

  // ── Shared implementation ───────────────────────────────────────────────

  Future<List<String>> _wishlistedIds(String userId, String entityType) async {
    final rows = await _client
        .from('wishlist')
        .select('entity_id')
        .eq('user_id', userId)
        .eq('entity_type', entityType)
        .order('added_at', ascending: false);
    return [for (final row in rows as List) row['entity_id'] as String];
  }

  Future<bool> _toggle({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    final alreadyIn = await _isWishlisted(
      userId: userId,
      entityType: entityType,
      entityId: entityId,
    );
    if (alreadyIn) {
      await _remove(userId: userId, entityType: entityType, entityId: entityId);
      return false;
    }
    await _add(userId: userId, entityType: entityType, entityId: entityId);
    return true;
  }

  Future<bool> _isWishlisted({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    final rows = await _client
        .from('wishlist')
        .select('user_id')
        .eq('user_id', userId)
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> _add({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    try {
      await _client.from('wishlist').insert({
        'user_id': userId,
        'entity_type': entityType,
        'entity_id': entityId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — already wishlisted, fine to ignore
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> _remove({
    required String userId,
    required String entityType,
    required String entityId,
  }) async {
    await _client
        .from('wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('entity_type', entityType)
        .eq('entity_id', entityId);
  }
}
