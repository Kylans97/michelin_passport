/// One of the cuisine groups members filter on (public.cuisine_families,
/// 20261101150000) — "Japanese" spans MICHELIN's Sushi, Tempura, Kaiseki
/// and the rest. A restaurant matches a family when any of its cuisines
/// belongs to it (restaurants_full.cuisine_family_slugs).
class CuisineFamily {
  final String slug;
  final String name;

  const CuisineFamily({required this.slug, required this.name});

  factory CuisineFamily.fromJson(Map<String, dynamic> json) =>
      CuisineFamily(slug: json['slug'] as String, name: json['name'] as String);

  @override
  bool operator ==(Object other) =>
      other is CuisineFamily && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}
