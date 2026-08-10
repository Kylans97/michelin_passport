import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;

// Explicit column list matching public.hotels_full as it exists on the
// CURRENT remote schema — see
// supabase/migrations/20260805141519_production_schema_v1.sql. Keep this in
// sync with Hotel.fromJson.
//
// Deliberately does NOT include latitude/longitude — see the matching note
// on restaurantFullColumns in restaurant_repository.dart. Same failure mode,
// same fix: coordinates are loaded separately by MapRepository, never by
// this shared, app-wide column list.
//
// Also deliberately does NOT include worlds_50_best_rank/worlds_50_best_year
// yet, for the identical reason: those columns only exist on hotels_full
// once supabase/migrations/20260807170000_expose_hotel_worlds_50_best_rank.sql
// is applied, and that migration is prepared but NOT applied remotely (see
// that file, and phase8/phase11 in the hotel catalogue expansion workspace).
// Requesting a column the live view doesn't have yet throws PostgREST error
// 42703 and takes down every caller of this constant — the entire hotel
// catalogue, not just the World's 50 Best-specific code paths. Hotel.
// worlds50BestRank/worlds50BestYear are modelled and ready; they simply
// resolve to null for every hotel fetched through this column list until
// migration + column list are updated together, in the same change.
const hotelFullColumns =
    'id, hotel_code, name, michelin_keys, city_name, region, country_code, '
    'country_name, flag_emoji, address, google_place_id, michelin_url, '
    'website_url, has_michelin_restaurant, restaurant_count';

class HotelRepository {
  HotelRepository(this._client);

  final SupabaseClient _client;

  // Full catalogue ordered by name.
  Future<List<Hotel>> getAll() async {
    final rows = await _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .order('name');
    return (rows as List)
        .map((row) => Hotel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // A single hotel by id, or null if it doesn't exist (or isn't visible
  // under RLS). Used to resolve the real Hotel before navigating there from
  // Restaurant Detail — never construct a Hotel from a restaurant row's
  // hotel_id/hotel_name alone, since restaurants_full doesn't expose the
  // rest of hotels_full's columns.
  Future<Hotel?> getById(String hotelId) async {
    final rows = await _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .eq('id', hotelId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Hotel.fromJson(list.first as Map<String, dynamic>);
  }

  // Search with optional Michelin Keys, World's 50 Best and country
  // filters. [countryCode] is the ISO 3166-1 alpha-2 code stored on
  // hotels_full, e.g. 'NL', 'BE', 'FR', 'ES'. [worlds50BestOnly] is an
  // independent alternative to [keys] in the Explore UI (its award filter
  // is a single-select), but nothing here enforces that — mirrors
  // RestaurantRepository.search()'s worlds50BestOnly exactly. Searches only
  // hotel-readable fields — name, city, country — never restaurant-only
  // fields like cuisine.
  //
  // NOTE: [worlds50BestOnly] filters/orders on hotels_full.worlds_50_best_rank,
  // a column that does not exist on the live view until
  // 20260807170000_expose_hotel_worlds_50_best_rank.sql is applied (see
  // hotelFullColumns above) — calling this with worlds50BestOnly: true
  // against the current remote schema throws a PostgREST 42703 error. This
  // is intentional: the code is ready, the data layer is not yet deployed.
  Future<List<Hotel>> search(
    String query, {
    int? keys,
    bool worlds50BestOnly = false,
    String? countryCode,
  }) async {
    var builder = _client.from('hotels_full').select(hotelFullColumns);

    if (query.isNotEmpty) {
      builder = builder.or(
        'name.ilike.%$query%,'
        'city_name.ilike.%$query%,'
        'country_name.ilike.%$query%',
      );
    }
    if (keys != null) {
      builder = builder.eq('michelin_keys', keys);
    }
    if (worlds50BestOnly) {
      builder = builder.not('worlds_50_best_rank', 'is', null);
    }
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }

    // World's 50 Best results read as a ranking, not a catalogue browse:
    // ordered by worlds_50_best_rank ascending (#1 first), mirroring
    // RestaurantRepository.search() exactly, including the same
    // `ascending: true` footgun this avoids (PostgrestTransformBuilder.order()
    // defaults to descending).
    final rows = worlds50BestOnly
        ? await builder.order('worlds_50_best_rank', ascending: true)
        : await builder.order('name');
    return (rows as List)
        .map((row) => Hotel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Countries that have at least one hotel, for the filter chips. Two
  // queries total, never one per country — mirrors
  // RestaurantRepository.getCountries(), sharing its countries-join logic
  // via resolveVenueCountries().
  Future<List<VenueCountry>> getCountries() async {
    final hotelRows = await _client.from('hotels_full').select('country_code');
    final presentCodes = <String>{
      for (final row in hotelRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }

  // Restaurants linked to this hotel via hotel_restaurants, resolved
  // directly off restaurants_full's hotel_id — that view already flattens
  // the hotel_restaurants join (see production schema), so this is one
  // query against restaurants_full, not a separate read of
  // hotel_restaurants plus N restaurant lookups.
  Future<List<Restaurant>> getLinkedRestaurants(String hotelId) async {
    final rows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .eq('hotel_id', hotelId)
        .order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
