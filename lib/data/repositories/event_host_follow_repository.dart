import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/events/event_host_qualification.dart';

/// Events V2 Step 8A — resolves "from a host you follow" relevance: which
/// of a caller-supplied set of event ids are hosted
/// (`event_restaurants`/`event_hotels`/`event_chefs`, qualification decided
/// by [eventHostFollowQualifies] — venue-only/participant-only never
/// qualify) by an entity the caller follows.
///
/// Composed entirely from existing public-read join tables plus the
/// caller's own owner-scoped `follows_*` rows — no `SECURITY DEFINER`
/// needed here (unlike `get_event_going_member_count`, which genuinely
/// counts other users' rows): `event_restaurants`/`event_hotels`/
/// `event_chefs` already have `qual: true` SELECT RLS, and `follows_*` is
/// already scoped to `auth.uid()` regardless of what [userId] this class is
/// called with, so a plain Dart-side join here leaks nothing the caller
/// couldn't already see two clicks away. Never called with anyone else's
/// user id in practice — see event_discovery_service.dart, the only
/// caller — but the RLS boundary holds either way (Step 8A §20).
///
/// A bounded number of queries regardless of how many events are being
/// checked: three to read the caller's own followed ids, up to three more
/// scoped to (followed ids × the requested event ids), then up to three
/// small name lookups — never one query per event, per follow, or per
/// followed-host match (Step 8A §14).
class EventHostFollowRepository {
  EventHostFollowRepository(this._client);

  final SupabaseClient _client;

  /// Every id in [eventIds] that is hosted by an entity [userId] follows,
  /// mapped to that entity's display name where cheaply resolved (null if
  /// not — the card falls back to a generic phrase either way). An id with
  /// no followed-host match is simply absent from the result map.
  Future<Map<String, String?>> getFollowedHostEventNames({
    required String userId,
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) return {};

    final followedRestaurantIdsFuture = _followedIds(
      table: 'follows_restaurants',
      column: 'restaurant_id',
      userId: userId,
    );
    final followedHotelIdsFuture = _followedIds(
      table: 'follows_hotels',
      column: 'hotel_id',
      userId: userId,
    );
    final followedChefIdsFuture = _followedIds(
      table: 'follows_private_chefs',
      column: 'private_chef_id',
      userId: userId,
    );
    final followedRestaurantIds = await followedRestaurantIdsFuture;
    final followedHotelIds = await followedHotelIdsFuture;
    final followedChefIds = await followedChefIdsFuture;

    if (followedRestaurantIds.isEmpty &&
        followedHotelIds.isEmpty &&
        followedChefIds.isEmpty) {
      return {};
    }

    final restaurantLinksFuture = followedRestaurantIds.isEmpty
        ? Future.value(const <_HostLinkRow>[])
        : _hostLinkRows(
            table: 'event_restaurants',
            entityColumn: 'restaurant_id',
            entityIds: followedRestaurantIds,
            eventIds: eventIds,
          );
    final hotelLinksFuture = followedHotelIds.isEmpty
        ? Future.value(const <_HostLinkRow>[])
        : _hostLinkRows(
            table: 'event_hotels',
            entityColumn: 'hotel_id',
            entityIds: followedHotelIds,
            eventIds: eventIds,
          );
    final chefLinksFuture = followedChefIds.isEmpty
        ? Future.value(const <_HostLinkRow>[])
        : _hostLinkRows(
            table: 'event_chefs',
            entityColumn: 'chef_id',
            entityIds: followedChefIds,
            eventIds: eventIds,
          );
    final restaurantLinks = (await restaurantLinksFuture)
        .where(
          (r) => eventHostFollowQualifies(isHost: r.isHost, isVenue: r.isVenue),
        )
        .toList();
    final hotelLinks = (await hotelLinksFuture)
        .where(
          (r) => eventHostFollowQualifies(isHost: r.isHost, isVenue: r.isVenue),
        )
        .toList();
    final chefLinks = (await chefLinksFuture)
        .where(
          (r) => eventHostFollowQualifies(isHost: r.isHost, isVenue: r.isVenue),
        )
        .toList();

    if (restaurantLinks.isEmpty && hotelLinks.isEmpty && chefLinks.isEmpty) {
      return {};
    }

    final restaurantNames = restaurantLinks.isEmpty
        ? const <String, String>{}
        : await _names(
            table: 'restaurants_full',
            ids: [for (final r in restaurantLinks) r.entityId],
          );
    final hotelNames = hotelLinks.isEmpty
        ? const <String, String>{}
        : await _names(
            table: 'hotels_full',
            ids: [for (final r in hotelLinks) r.entityId],
          );
    final chefNames = chefLinks.isEmpty
        ? const <String, String>{}
        : await _names(
            table: 'private_chefs',
            ids: [for (final r in chefLinks) r.entityId],
            nameColumn: 'display_name',
          );

    final result = <String, String?>{};
    for (final link in restaurantLinks) {
      result[link.eventId] = restaurantNames[link.entityId];
    }
    for (final link in hotelLinks) {
      result.putIfAbsent(link.eventId, () => hotelNames[link.entityId]);
    }
    for (final link in chefLinks) {
      result.putIfAbsent(link.eventId, () => chefNames[link.entityId]);
    }
    return result;
  }

  Future<List<String>> _followedIds({
    required String table,
    required String column,
    required String userId,
  }) async {
    final rows = await _client.from(table).select(column).eq('user_id', userId);
    return [for (final row in rows as List) row[column] as String];
  }

  Future<List<_HostLinkRow>> _hostLinkRows({
    required String table,
    required String entityColumn,
    required List<String> entityIds,
    required List<String> eventIds,
  }) async {
    final rows = await _client
        .from(table)
        .select('event_id, $entityColumn, is_host, is_venue')
        .inFilter(entityColumn, entityIds)
        .inFilter('event_id', eventIds);
    return [
      for (final row in rows as List)
        _HostLinkRow(
          eventId: row['event_id'] as String,
          entityId: row[entityColumn] as String,
          isHost: row['is_host'] as bool? ?? false,
          isVenue: row['is_venue'] as bool? ?? false,
        ),
    ];
  }

  Future<Map<String, String>> _names({
    required String table,
    required List<String> ids,
    String nameColumn = 'name',
  }) async {
    final rows = await _client
        .from(table)
        .select('id, $nameColumn')
        .inFilter('id', ids);
    return {
      for (final row in rows as List)
        if ((row[nameColumn] as String?)?.isNotEmpty ?? false)
          (row['id'] as String): row[nameColumn] as String,
    };
  }
}

class _HostLinkRow {
  final String eventId;
  final String entityId;
  final bool isHost;
  final bool isVenue;
  const _HostLinkRow({
    required this.eventId,
    required this.entityId,
    required this.isHost,
    required this.isVenue,
  });
}
