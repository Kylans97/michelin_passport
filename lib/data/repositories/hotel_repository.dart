import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;
import 'search_query.dart';

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
// worlds_50_best_rank/worlds_50_best_year ARE now included:
// 20260807150000_hotel_michelin_keys_nullable.sql,
// 20260807160000_create_worlds_50_best_hotels.sql and
// 20260807170000_expose_hotel_worlds_50_best_rank.sql are all applied on
// the live schema (production deployment confirmed complete) — hotels_full
// genuinely exposes both columns now, so every caller of this constant
// (Explore, Passport, Rankings, Detail, Wishlist) receives real values,
// not the permanent nulls this list previously guaranteed.
const hotelFullColumns =
    'id, hotel_code, name, michelin_keys, city_name, region, country_code, '
    'country_name, flag_emoji, address, google_place_id, michelin_url, '
    'website_url, booking_url, has_michelin_restaurant, restaurant_count, '
    'worlds_50_best_rank, worlds_50_best_year';

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
  // [keysOnly] restricts to hotels that currently hold a confirmed Key
  // value (michelin_keys is not null) — mirrors
  // RestaurantRepository.search()'s [starsOnly] exactly, added for Guides'
  // Michelin Hotels catalogue (Step 2B). Explore never passes this
  // (defaults false), so its own "All" hotel search — which intentionally
  // includes Key-less hotels — is unaffected.
  Future<List<Hotel>> search(
    String query, {
    int? keys,
    bool keysOnly = false,
    bool worlds50BestOnly = false,
    String? countryCode,
  }) async {
    var builder = _client.from('hotels_full').select(hotelFullColumns);

    final orFilter = buildIlikeOrFilter(query, [
      'name',
      'city_name',
      'country_name',
    ]);
    if (orFilter != null) {
      builder = builder.or(orFilter);
    }
    if (keys != null) {
      builder = builder.eq('michelin_keys', keys);
    } else if (keysOnly) {
      builder = builder.not('michelin_keys', 'is', null);
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
  //
  // [keysOnly] narrows the first query to hotels with a confirmed Key value
  // only — mirrors RestaurantRepository.getCountries()'s [starsOnly]
  // exactly, used by Guides' Michelin Hotels catalogue (Step 2B). Explore
  // never passes this (defaults false), so its own country list is
  // unaffected.
  Future<List<VenueCountry>> getCountries({bool keysOnly = false}) async {
    var query = _client.from('hotels_full').select('country_code');
    if (keysOnly) {
      query = query.not('michelin_keys', 'is', null);
    }
    final hotelRows = await query;
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
