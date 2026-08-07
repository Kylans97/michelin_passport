import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';

// Explicit column list matching public.restaurants_full as it exists on the
// CURRENT remote schema — see
// supabase/migrations/20260805141519_production_schema_v1.sql. Keep this in
// sync with Restaurant.fromJson. Public because visited_repository.dart and
// wishlist_repository.dart also resolve restaurants_full rows by id.
//
// Deliberately does NOT include latitude/longitude. Those columns only
// exist once supabase/migrations/20260807140000_add_venue_coordinates.sql
// is applied — until then, requesting them here throws PostgREST error
// 42703 ("column ... does not exist") and takes down every caller of this
// constant (Explore, Passport, Rankings, Detail, Wishlist, Visits/Stays —
// i.e. the entire catalogue). Coordinates for the Map feature are loaded
// separately and only there — see MapRepository.
const restaurantFullColumns =
    'id, restaurant_code, name, michelin_stars, inclusion_reason, '
    'city_name, region, country_code, country_name, flag_emoji, address, '
    'google_place_id, michelin_url, website_url, booking_url, property_name, '
    'is_in_hotel, hotel_id, hotel_name, worlds_50_best_rank';

class RestaurantRepository {
  RestaurantRepository(this._client);

  final SupabaseClient _client;

  // Full catalogue ordered by name.
  Future<List<Restaurant>> getAll() async {
    final rows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Search with optional Michelin star, award and country filters.
  // [countryCode] is the ISO 3166-1 alpha-2 code stored on restaurants_full,
  // e.g. 'NL', 'BE', 'FR', 'ES'. [worlds50BestOnly] and [hallOfFameOnly] are
  // mutually exclusive alternatives to [stars] in the Explore UI (its award
  // filter is a single-select), but nothing here enforces that — each is
  // applied independently, ANDed together, whichever are non-null/true.
  Future<List<Restaurant>> search(
    String query, {
    int? stars,
    bool worlds50BestOnly = false,
    bool hallOfFameOnly = false,
    String? countryCode,
  }) async {
    var builder = _client
        .from('restaurants_full')
        .select(restaurantFullColumns);

    if (query.isNotEmpty) {
      builder = builder.or(
        'name.ilike.%$query%,'
        'city_name.ilike.%$query%,'
        'country_name.ilike.%$query%',
      );
    }
    if (stars != null) {
      builder = builder.eq('michelin_stars', stars);
    }
    if (worlds50BestOnly) {
      builder = builder.not('worlds_50_best_rank', 'is', null);
    }
    if (hallOfFameOnly) {
      builder = builder.eq('inclusion_reason', 'hall_of_fame');
    }
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }

    // World's 50 Best results read as a ranking, not a catalogue browse:
    // ordered by worlds_50_best_rank ascending (#1, #2, #3, ...) rather
    // than alphabetically, regardless of any country filter also applied
    // above. Every other filter (including "all" and Hall of Fame) keeps
    // the usual alphabetical-by-name order.
    //
    // `ascending` must be passed explicitly — PostgrestTransformBuilder.order()
    // defaults to `ascending: false` (descending), not true, so an
    // unqualified .order('worlds_50_best_rank') silently rendered #50 first.
    final rows = worlds50BestOnly
        ? await builder.order('worlds_50_best_rank', ascending: true)
        : await builder.order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Countries that have at least one restaurant, for the filter chips.
  // Two queries total, never one per country: the distinct country_code
  // values present on restaurants_full, resolved against public.countries
  // by the shared resolveVenueCountries() helper (also used by
  // HotelRepository.getCountries()).
  Future<List<VenueCountry>> getCountries() async {
    final restaurantRows = await _client
        .from('restaurants_full')
        .select('country_code');
    final presentCodes = <String>{
      for (final row in restaurantRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }
}
