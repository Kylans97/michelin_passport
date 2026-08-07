// Maps a row from `public.hotels_full` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). Only fields
// the view actually exposes are modelled — see that view's SELECT list
// before adding anything here.
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

  // 1-3. Unlike Restaurant.michelinStars, this is never null: public.hotels
  // enforces `michelin_keys smallint not null check (between 1 and 3)` —
  // every row in the catalogue holds at least one Michelin Key by
  // definition.
  final int michelinKeys;

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
  });

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
    id: json['id'].toString(),
    hotelCode: (json['hotel_code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    michelinKeys: (json['michelin_keys'] as num?)?.toInt() ?? 0,
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
  );
}
