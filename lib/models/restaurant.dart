// Maps a row from `public.restaurants_full` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). Only fields
// the view actually exposes are modelled — see that view's SELECT list
// before adding anything here.
class Restaurant {
  final String id;
  final String restaurantCode;
  final String name;

  // NULL means the restaurant does not currently hold a Michelin star. It is
  // never coerced to 0 — see DATABASE_ARCHITECTURE.md section 3.3.
  final int? michelinStars;

  final String inclusionReason;

  final String cityName;
  final String? region;
  final String countryCode;
  final String countryName;
  final String flagEmoji;

  final String address;

  final String? googlePlaceId;
  final String? michelinUrl;
  final String? websiteUrl;
  final String? bookingUrl;

  // Non-null only for a restaurant inside a non-Key hotel.
  final String? propertyName;

  // True when a hotel_restaurants link exists OR propertyName is set.
  final bool isInHotel;
  final String? hotelId;
  final String? hotelName;

  final int? worlds50BestRank;

  // `location` is PostGIS geography(Point,4326). Over PostgREST it comes
  // back as an EWKB hex string (e.g. "0101000020E6100000..."), not GeoJSON
  // or a {lat, lng} pair, and restaurants_full does not separately expose
  // ST_Y/ST_X. Decoding EWKB client-side isn't safe to guess at, and Explore
  // doesn't need coordinates, so these stay null rather than a wrong parse.
  final double? latitude;
  final double? longitude;

  const Restaurant({
    required this.id,
    required this.restaurantCode,
    required this.name,
    required this.michelinStars,
    required this.inclusionReason,
    required this.cityName,
    this.region,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.address,
    this.googlePlaceId,
    this.michelinUrl,
    this.websiteUrl,
    this.bookingUrl,
    this.propertyName,
    this.isInHotel = false,
    this.hotelId,
    this.hotelName,
    this.worlds50BestRank,
    this.latitude,
    this.longitude,
  });

  /// True when the restaurant currently holds at least one Michelin star.
  bool get hasMichelinStar => michelinStars != null;

  /// True when the restaurant has a current World's 50 Best rank.
  bool get isWorlds50Best => worlds50BestRank != null;

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'].toString(),
    restaurantCode: (json['restaurant_code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    michelinStars: (json['michelin_stars'] as num?)?.toInt(),
    inclusionReason: (json['inclusion_reason'] as String?) ?? '',
    cityName: (json['city_name'] as String?) ?? '',
    region: json['region'] as String?,
    countryCode: (json['country_code'] as String?) ?? '',
    countryName: (json['country_name'] as String?) ?? '',
    flagEmoji: (json['flag_emoji'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    googlePlaceId: json['google_place_id'] as String?,
    michelinUrl: json['michelin_url'] as String?,
    websiteUrl: json['website_url'] as String?,
    bookingUrl: json['booking_url'] as String?,
    propertyName: json['property_name'] as String?,
    isInHotel: (json['is_in_hotel'] as bool?) ?? false,
    hotelId: json['hotel_id'] as String?,
    hotelName: json['hotel_name'] as String?,
    worlds50BestRank: (json['worlds_50_best_rank'] as num?)?.toInt(),
    // latitude/longitude intentionally left null — see field docs above.
  );
}
