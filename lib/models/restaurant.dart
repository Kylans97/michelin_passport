class Restaurant {
  final String id;
  final String name;
  final int michelinStars;
  final String cuisine;
  final String city;
  final String country;
  final String countryFlag;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId;
  final String? michelinUrl;

  const Restaurant({
    required this.id,
    required this.name,
    required this.michelinStars,
    required this.cuisine,
    required this.city,
    required this.country,
    required this.countryFlag,
    required this.address,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.michelinUrl,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'].toString(),
        name: (json['name'] as String?) ?? '',
        michelinStars: (json['michelin_stars'] as int?) ?? 0,
        cuisine: (json['cuisine'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        country: (json['country'] as String?) ?? '',
        countryFlag: (json['country_flag'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        googlePlaceId: json['google_place_id'] as String?,
        michelinUrl: json['michelin_url'] as String?,
      );
}
