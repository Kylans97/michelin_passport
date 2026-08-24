import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'search_query.dart';

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
//
// is_hall_of_fame has the identical deployment-ordering hazard: it only
// exists once
// supabase/migrations/20260811220000_gault_millau_provenance_and_hall_of_fame_fix.sql
// is applied to whatever schema this code runs against. Confirmed deployed
// to production (queried directly). Unlike lat/lon, it was included here
// directly rather than split into a second constant, because (unlike the
// Map feature's coordinate-only query) every caller of
// restaurantFullColumns needs Restaurant.isHallOfFame to work correctly
// (RestaurantAwardsCard, Explore's Hall of Fame filter), so there is no
// meaningful subset of callers this column could be safely deferred for.
//
// phone (Restaurant Enrichment Step 1D) has the same deployment-ordering
// hazard, deliberately accepted for the same reason — VenueUtilityActions'
// Call action needs it wherever Restaurant Detail is shown, so there is no
// subset of callers to safely split it out for either. Do not query this
// constant against an environment where
// supabase/migrations/20260819120000_add_restaurant_phone.sql has not
// been applied.
const restaurantFullColumns =
    'id, restaurant_code, name, michelin_stars, inclusion_reason, '
    'city_name, region, country_code, country_name, flag_emoji, address, '
    'google_place_id, michelin_url, website_url, booking_url, phone, '
    'property_name, is_in_hotel, hotel_id, hotel_name, worlds_50_best_rank, '
    'is_hall_of_fame';

class RestaurantRepository {
  RestaurantRepository(this._client);

  final SupabaseClient _client;

  // One restaurant by id — a cheap, single-row fetch against the same
  // restaurants_full columns getAll()/search() already use. Added for
  // Community's "Hot Right Now" hero (community_screen.dart): a
  // CommunityRankingEntry only carries a restaurant_id plus a handful of
  // summary fields, not enough to push RestaurantDetailScreen (which
  // requires a full Restaurant), so the detail screen resolves the full
  // row on tap rather than the summary list eagerly fetching one.
  Future<Restaurant?> getById(String id) async {
    final row = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Restaurant.fromJson(row);
  }

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
  //
  // [starsOnly] restricts to restaurants that currently hold ANY Michelin
  // star (michelin_stars is not null) — added for Guides' Michelin
  // Restaurants catalogue (Step 2B), which must only ever browse currently-
  // starred restaurants, including when no specific [stars] tier is
  // selected. Explore never passes this (defaults false), so its "All"
  // restaurant search — which intentionally includes unstarred
  // restaurants — is unaffected.
  Future<List<Restaurant>> search(
    String query, {
    int? stars,
    bool starsOnly = false,
    bool worlds50BestOnly = false,
    bool hallOfFameOnly = false,
    String? countryCode,
  }) async {
    var builder = _client
        .from('restaurants_full')
        .select(restaurantFullColumns);

    final orFilter = buildIlikeOrFilter(query, [
      'name',
      'city_name',
      'country_name',
    ]);
    if (orFilter != null) {
      builder = builder.or(orFilter);
    }
    if (stars != null) {
      builder = builder.eq('michelin_stars', stars);
    } else if (starsOnly) {
      builder = builder.not('michelin_stars', 'is', null);
    }
    if (worlds50BestOnly) {
      builder = builder.not('worlds_50_best_rank', 'is', null);
    }
    if (hallOfFameOnly) {
      // is_hall_of_fame, not inclusion_reason — inclusion_reason is
      // creation provenance only and is never actually set to
      // 'hall_of_fame' by the import path (every current Hall of Fame
      // member also holds a Michelin star, so import always picks
      // 'michelin_star' instead); filtering on it here previously matched
      // zero real restaurants. is_hall_of_fame is the authoritative,
      // correctly-derived column — see restaurants_full's definition.
      builder = builder.eq('is_hall_of_fame', true);
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
  //
  // [starsOnly] narrows the first query to currently-starred restaurants
  // only — Guides' Michelin Restaurants catalogue (Step 2B) uses this so
  // its country picker never offers a country whose only restaurants are
  // unstarred. Explore never passes this (defaults false), so its own
  // country list is unaffected.
  Future<List<VenueCountry>> getCountries({bool starsOnly = false}) async {
    var query = _client.from('restaurants_full').select('country_code');
    if (starsOnly) {
      query = query.not('michelin_stars', 'is', null);
    }
    final restaurantRows = await query;
    final presentCodes = <String>{
      for (final row in restaurantRows as List)
        if ((row['country_code'] as String?)?.isNotEmpty ?? false)
          row['country_code'] as String,
    };
    return resolveVenueCountries(_client, presentCodes);
  }
}
