// Maps a row from `public.hotels_full` (see
// supabase/migrations/20260805141519_production_schema_v1.sql, and
// supabase/migrations/20260807150000_hotel_michelin_keys_nullable.sql /
// 20260807170000_expose_hotel_worlds_50_best_rank.sql, both prepared but not
// yet applied remotely — see hotelFullColumns in hotel_repository.dart for
// why worlds_50_best_rank/year aren't requested yet even though they're
// modelled here). Only fields the view actually exposes are modelled — see
// that view's SELECT list before adding anything here.
//
// No latitude/longitude here — see the matching note on Restaurant in
// restaurant.dart. hotels_full can project scalar coordinates once the
// 20260807140000 migration is applied, but hotelFullColumns deliberately
// excludes them so every other feature keeps working regardless; the Map
// feature reads coordinates directly via MapRepository instead.
// hotels_full also has no property_name-equivalent column: unlike a
// restaurant, which can optionally sit inside a non-Key hotel property, a
// hotel row *is* the property, so there is nothing analogous to resolve.
class Hotel {
  final String id;
  final String hotelCode;
  final String name;

  // NULL means "no confirmed MICHELIN Key value is currently stored for
  // this hotel" — it is never coerced to 0, and it does NOT mean the hotel
  // holds zero Keys, has no Michelin recognition, or is ineligible for the
  // catalogue. A hotel can be catalogue-eligible purely through World's 50
  // Best history (see isWorlds50Best) with michelinKeys permanently null,
  // just as Restaurant.michelinStars has always worked for restaurants.
  // See supabase/migrations/20260807150000_hotel_michelin_keys_nullable.sql
  // for the full semantics this mirrors, and
  // supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
  // phase6_flutter_key_nullability_audit.md for the audit that drove this
  // change.
  final int? michelinKeys;

  final String cityName;
  final String? region;
  final String countryCode;
  final String countryName;
  final String flagEmoji;

  final String address;

  final String? googlePlaceId;
  final String? michelinUrl;
  final String? websiteUrl;

  // Derived by hotels_full from a left join against hotel_restaurants,
  // grouped server-side — never a second query per hotel.
  final bool hasMichelinRestaurant;
  final int restaurantCount;

  // The hotel's CURRENT (most recent ranked year's) World's 50 Best Hotels
  // position, mirroring Restaurant.worlds50BestRank — a derived column from
  // a left join against public.worlds_50_best_hotels, not a raw table
  // field. Both null together or non-null together; there is no state
  // where one is set without the other. See hotelFullColumns: these are
  // deliberately NOT requested yet, since the view migration that would
  // expose them hasn't been applied remotely — every Hotel parsed via that
  // column list has both null today, by construction, until it ships.
  final int? worlds50BestRank;
  final int? worlds50BestYear;

  const Hotel({
    required this.id,
    required this.hotelCode,
    required this.name,
    required this.michelinKeys,
    required this.cityName,
    this.region,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.address,
    this.googlePlaceId,
    this.michelinUrl,
    this.websiteUrl,
    required this.hasMichelinRestaurant,
    required this.restaurantCount,
    this.worlds50BestRank,
    this.worlds50BestYear,
  });

  /// True when the hotel currently holds a confirmed MICHELIN Key value.
  /// The mirror of Restaurant.hasMichelinStar — use this, never a null
  /// check on michelinKeys directly, so the intent reads the same way at
  /// every call site.
  bool get hasMichelinKeys => michelinKeys != null;

  /// True when the hotel has a current World's 50 Best Hotels rank.
  bool get isWorlds50Best => worlds50BestRank != null;

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
    id: json['id'].toString(),
    hotelCode: (json['hotel_code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    michelinKeys: (json['michelin_keys'] as num?)?.toInt(),
    cityName: (json['city_name'] as String?) ?? '',
    region: json['region'] as String?,
    countryCode: (json['country_code'] as String?) ?? '',
    countryName: (json['country_name'] as String?) ?? '',
    flagEmoji: (json['flag_emoji'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    googlePlaceId: json['google_place_id'] as String?,
    michelinUrl: json['michelin_url'] as String?,
    websiteUrl: json['website_url'] as String?,
    hasMichelinRestaurant: (json['has_michelin_restaurant'] as bool?) ?? false,
    restaurantCount: (json['restaurant_count'] as num?)?.toInt() ?? 0,
    worlds50BestRank: (json['worlds_50_best_rank'] as num?)?.toInt(),
    worlds50BestYear: (json['worlds_50_best_year'] as num?)?.toInt(),
  );
}
