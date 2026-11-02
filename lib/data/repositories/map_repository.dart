import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import 'fetch_all_rows.dart';
import 'hotel_repository.dart';
import 'restaurant_repository.dart';

// PostgREST's "column does not exist" error — what a request for
// latitude/longitude returns before the 20260807140000 migration has been
// applied to restaurants_full/hotels_full.
const _undefinedColumnErrorCode = '42703';

/// Coordinate-only queries for the Map feature, deliberately isolated from
/// [restaurantFullColumns]/[hotelFullColumns] in restaurant_repository.dart
/// / hotel_repository.dart.
///
/// Those two constants are shared by every catalogue-reading feature
/// (Explore, Passport, Rankings, Detail, Wishlist, Visits/Stays) and must
/// keep working against the CURRENT remote schema regardless of whether the
/// coordinate migration has landed — so latitude/longitude are requested
/// nowhere else but here, and only for the specific venue ids the Map
/// screen actually needs (never the full catalogue).
///
/// Returns raw id -> (lat, lng) maps rather than Restaurant/Hotel objects:
/// the Map screen already has fully-formed Restaurant/Hotel instances from
/// VisitedRepository.loadPassportVenues, it only needs coordinates merged
/// in by id.
class MapRepository {
  MapRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, (double, double)>> loadRestaurantCoordinates(
    Iterable<String> ids,
  ) => _loadCoordinates('restaurants_full', ids);

  Future<Map<String, (double, double)>> loadHotelCoordinates(
    Iterable<String> ids,
  ) => _loadCoordinates('hotels_full', ids);

  // Never throws: if the migration hasn't been applied yet, PostgREST
  // reports that as error 42703 on latitude/longitude, which degrades to an
  // empty map here (no pins, but the map screen itself — tiles, filters,
  // empty state — is entirely unaffected). Any other failure (network,
  // RLS, etc.) degrades the same way, logged rather than silently dropped,
  // since a coordinate hiccup should never take down the whole Map screen.
  Future<Map<String, (double, double)>> _loadCoordinates(
    String view,
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return {};
    try {
      final rows = await _client
          .from(view)
          .select('id, latitude, longitude')
          .inFilter('id', idList);
      final result = <String, (double, double)>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          result[row['id'].toString()] = (lat, lng);
        }
      }
      return result;
    } on PostgrestException catch (e) {
      if (e.code == _undefinedColumnErrorCode) {
        debugPrint(
          'MapRepository: $view.latitude/longitude not available yet '
          '(coordinate migration not applied) — showing no pins.',
        );
        return {};
      }
      debugPrint('MapRepository: failed to load coordinates from $view: $e');
      return {};
    } catch (e) {
      debugPrint('MapRepository: failed to load coordinates from $view: $e');
      return {};
    }
  }

  /// Every restaurant and hotel in a trip leg's place — the cities in
  /// [cityIds], or the whole countries in [countryCodes] — with its
  /// coordinates, for the trip map. Keyed on catalogue ids and codes only,
  /// never a name. Venues without coordinates, expired pop-ups and
  /// permanently closed venues are left out: there is nothing to plan
  /// there. Temporarily closed venues stay, as their detail page says so.
  ///
  /// Unlike [loadRestaurantCoordinates], this one is allowed to throw: the
  /// trip map has nothing to show without it, and says so.
  Future<List<MappedVenue>> loadVenuesInPlaces({
    List<String> countryCodes = const [],
    List<String> cityIds = const [],
  }) async {
    if (countryCodes.isEmpty && cityIds.isEmpty) return [];
    final place = [
      if (cityIds.isNotEmpty) 'city_id.in.(${cityIds.join(',')})',
      if (countryCodes.isNotEmpty) 'country_code.in.(${countryCodes.join(',')})',
    ].join(',');

    // A whole-country leg in France or Japan matches hundreds of rows, so
    // page past the row cap.
    final results = await Future.wait([
      fetchAllRows(
        () => _client
            .from('restaurants_full')
            .select('$restaurantFullColumns, latitude, longitude')
            .or(place)
            .order('id', ascending: true),
      ),
      fetchAllRows(
        () => _client
            .from('hotels_full')
            .select('$hotelFullColumns, latitude, longitude')
            .or(place)
            .order('id', ascending: true),
      ),
    ]);

    final mapped = <MappedVenue>[];
    for (final row in results[0]) {
      final restaurant = Restaurant.fromJson(row);
      if (restaurant.isExpired || restaurant.isPermanentlyClosed) continue;
      final point = _point(row);
      if (point != null) mapped.add(MappedVenue(RestaurantVenue(restaurant), point.$1, point.$2));
    }
    for (final row in results[1]) {
      final hotel = Hotel.fromJson(row);
      if (hotel.isExpired || hotel.isPermanentlyClosed) continue;
      final point = _point(row);
      if (point != null) mapped.add(MappedVenue(HotelVenue(hotel), point.$1, point.$2));
    }
    return mapped;
  }

  static (double, double)? _point(Map<String, dynamic> row) {
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    return lat == null || lng == null ? null : (lat, lng);
  }
}

/// A catalogue venue with its coordinates — see
/// [MapRepository.loadVenuesInPlaces].
class MappedVenue {
  final PassportVenue venue;
  final double latitude;
  final double longitude;

  const MappedVenue(this.venue, this.latitude, this.longitude);
}
