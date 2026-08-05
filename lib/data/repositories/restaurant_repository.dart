import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';

// Explicit column list matching public.restaurants_full — see
// supabase/migrations/20260805141519_production_schema_v1.sql. Keep this in
// sync with Restaurant.fromJson. Public because visited_repository.dart and
// wishlist_repository.dart also resolve restaurants_full rows by id.
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

  // Search with optional Michelin star and country filters.
  // [countryCode] is the ISO 3166-1 alpha-2 code stored on restaurants_full,
  // e.g. 'NL', 'BE', 'FR', 'ES'.
  Future<List<Restaurant>> search(
    String query, {
    int? stars,
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
    if (countryCode != null) {
      builder = builder.eq('country_code', countryCode);
    }

    final rows = await builder.order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Countries that have at least one restaurant, for the filter chips.
  // Two queries total, never one per country: the distinct country_code
  // values present on restaurants_full, joined in Dart against one read of
  // public.countries.
  Future<List<RestaurantCountry>> getCountries() async {
    final restaurantRows = await _client
        .from('restaurants_full')
        .select('country_code');
    final presentCodes = <String>{
      for (final row in restaurantRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };

    final countryRows = await _client
        .from('countries')
        .select('country_code, name, flag_emoji')
        .order('name');

    return [
      for (final row in countryRows as List)
        if (presentCodes.contains(row['country_code'] as String?))
          RestaurantCountry(
            name: (row['name'] as String?) ?? '',
            code: (row['country_code'] as String?) ?? '',
            flag: (row['flag_emoji'] as String?) ?? '',
          ),
    ];
  }
}

// Simple value object used by the Explore screen for country filter chips.
class RestaurantCountry {
  final String name;
  final String code;
  final String flag;
  const RestaurantCountry({
    required this.name,
    required this.code,
    required this.flag,
  });
}
