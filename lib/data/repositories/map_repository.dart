import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
