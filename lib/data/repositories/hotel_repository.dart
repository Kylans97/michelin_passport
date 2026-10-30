import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/published_venue_photo.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart';
import 'fetch_all_rows.dart';
import 'fetch_leaders.dart';
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
// starts_on/ends_on/parent_venue_type/parent_venue_id/opening_weekdays
// (pop-ups and temporary venues) and is_expired both added by
// 20260829150000_add_popup_expiry_to_views_and_search.sql.
// status/status_since/status_note — see the identical note on
// restaurantFullColumns in restaurant_repository.dart.
// created_at/missing_listing_report_id (Fresh Finds, 20260924140000_add_
// missing_listing_report_link.sql) — see restaurantFullColumns' own
// matching comment.
// cover_photo_url (20261006120000_add_cover_photo_url_to_full_views.sql) —
// see restaurantFullColumns' own matching comment.
// phone (20261016130000_add_hotel_phone.sql) — same deployment-ordering
// hazard as restaurants' phone: that migration must be applied before a
// build carrying this list ships, or every hotels_full select fails.
// worlds_50_best_url (20261021120000_add_worlds_50_best_urls.sql) — same
// ordering hazard: the migration must be live before this ships.
const hotelFullColumns =
    'id, hotel_code, name, michelin_keys, city_id, city_name, region, country_code, '
    'country_name, flag_emoji, address, google_place_id, michelin_url, '
    'website_url, booking_url, has_michelin_restaurant, restaurant_count, '
    'worlds_50_best_rank, worlds_50_best_year, starts_on, ends_on, '
    'parent_venue_type, parent_venue_id, opening_weekdays, is_expired, '
    'status, status_since, status_note, created_at, missing_listing_report_id, '
    'cover_photo_url, cover_focus_x, cover_focus_y, cover_zoom, card_photo_url, '
    'card_focus_x, card_focus_y, card_zoom, phone, worlds_50_best_url';

class HotelRepository {
  HotelRepository(this._client);

  final SupabaseClient _client;

  // Every published photo for one hotel, in display_order — see
  // RestaurantRepository.getPhotos' own doc comment for why this is
  // deliberately not on hotels_full/hotelFullColumns, and for why this
  // returns the full row (id included) rather than bare urls.
  Future<List<PublishedVenuePhoto>> getPhotos(String hotelId) async {
    final rows = await _client
        .from('hotel_photos')
        .select(
          'id, image_url, alt_text, display_order, focus_x, focus_y, zoom, is_card, card_focus_x, card_focus_y, card_zoom',
        )
        .eq('hotel_id', hotelId)
        // ascending: postgrest-dart's order() defaults to DESCENDING, which put
        // the highest display_order first — the reverse of the cover every card
        // shows (restaurants_full/hotels_full take the lowest).
        .order('display_order', ascending: true);
    return [
      for (final row in rows as List)
        PublishedVenuePhoto.fromJson(row as Map<String, dynamic>),
    ];
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

  // Explore's Stay a Little Longer candidates — RestaurantRepository.
  // getDiscoveryCandidates() with Keys in place of stars; the caller picks
  // with selectDiscoveryHotels.
  Future<List<Hotel>> getDiscoveryCandidates({int limit = 8}) async {
    final rows = await fetchLeaderCandidates(
      select: () => _client.from('hotels_full').select(hotelFullColumns),
      primaryKey: 'michelin_keys',
      secondaryKey: 'worlds_50_best_rank',
      limit: limit,
    );
    return rows.map(Hotel.fromJson).toList();
  }

  // Explore's Fresh Finds candidates — see RestaurantRepository.
  // getFreshFindCandidates().
  Future<List<Hotel>> getFreshFindCandidates({int limit = 10}) async {
    final rows = await _client
        .from('hotels_full')
        .select(hotelFullColumns)
        .not('missing_listing_report_id', 'is', null)
        .not('created_at', 'is', null)
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .limit(limit);
    return rows.map(Hotel.fromJson).toList();
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
  /// Trips' venue pickers: [query] (same per-word matching as [search])
  /// limited to a trip's destinations — venues in any of [cityIds] or in
  /// any of [countryCodes] (whole-country legs). Keyed on catalogue codes
  /// and ids only, never on a name, never on `property_name`. Sorted A→Z
  /// (`ascending` explicit — postgrest-dart's default is descending).
  Future<List<Hotel>> searchInPlaces(
    String query, {
    List<String> countryCodes = const [],
    List<String> cityIds = const [],
  }) async {
    if (countryCodes.isEmpty && cityIds.isEmpty) return [];
    PostgrestFilterBuilder<PostgrestList> filtered() {
      var builder = _client.from('hotels_full').select(hotelFullColumns);
      for (final filter in buildIlikeOrFilters(query, [
        'name',
        'city_name',
        'country_name',
      ])) {
        builder = builder.or(filter);
      }
      return builder.or(
        [
          if (cityIds.isNotEmpty) 'city_id.in.(${cityIds.join(',')})',
          if (countryCodes.isNotEmpty)
            'country_code.in.(${countryCodes.join(',')})',
        ].join(','),
      );
    }

    // Paged past the row cap, like RestaurantRepository.searchInPlaces.
    final rows = await fetchAllRows(
      () => filtered()
          .order('is_expired', ascending: true)
          .order('name', ascending: true)
          .order('id', ascending: true),
    );
    return rows.map(Hotel.fromJson).toList();
  }

  Future<List<Hotel>> search(
    String query, {
    int? keys,
    bool keysOnly = false,
    bool worlds50BestOnly = false,
    String? countryCode,
  }) async {
    PostgrestFilterBuilder<PostgrestList> filtered() {
      var builder = _client.from('hotels_full').select(hotelFullColumns);

      // One .or() call per word in [query] — mirrors
      // RestaurantRepository.search() exactly; see buildIlikeOrFilters()'s
      // doc comment for why chained .or() calls AND together instead of
      // overwriting, and why a single-word query is unaffected.
      for (final filter in buildIlikeOrFilters(query, [
        'name',
        'city_name',
        'country_name',
      ])) {
        builder = builder.or(filter);
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
      return builder;
    }

    // Pop-ups: SQL-side sort, is_expired as the primary key — see
    // RestaurantRepository.search()'s own comment for the full reasoning
    // (why is_expired and not raw ends_on, why chained .order() and not
    // a client-side re-sort).
    //
    // World's 50 Best results read as a ranking, not a catalogue browse:
    // ordered by worlds_50_best_rank ascending (#1 first) as the
    // secondary key, mirroring RestaurantRepository.search() exactly,
    // including the same `ascending: true` footgun this avoids
    // (PostgrestTransformBuilder.order() defaults to descending).
    //
    // Paged past PostgREST's row cap, `id` last for stable pages — see
    // RestaurantRepository.search() and fetchAllRows.
    final rows = await fetchAllRows(
      () => worlds50BestOnly
          ? filtered()
                .order('is_expired', ascending: true)
                .order('worlds_50_best_rank', ascending: true)
                .order('id', ascending: true)
          : filtered()
                .order('is_expired', ascending: true)
                .order('name')
                .order('id', ascending: true),
    );
    return rows.map(Hotel.fromJson).toList();
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
    //
    // Paged past PostgREST's row cap, like RestaurantRepository.
    // getCountries() — hotels are close to 1000 rows.
    final hotelRows = await fetchAllRows(() {
      var query = _client.from('hotels_full').select('country_code, id');
      if (keysOnly) {
        query = query.not('michelin_keys', 'is', null);
      }
      return query.order('id', ascending: true);
    });
    final presentCodes = <String>{
      for (final row in hotelRows)
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
