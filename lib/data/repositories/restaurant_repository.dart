import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository(this._client);

  final SupabaseClient _client;

  // Full catalogue ordered alphabetically.
  Future<List<Restaurant>> getAll() async {
    final rows = await _client.from('restaurants').select().order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Search with optional star, country, and category filters.
  // [countryCode] is a 2-letter ISO code: 'NL', 'BE', 'FR', 'ES', etc.
  Future<List<Restaurant>> search(
    String query, {
    int? stars,
    String? countryCode,
    String? category,
  }) async {
    var builder = _client.from('restaurants').select();

    if (query.isNotEmpty) {
      builder = builder.or(
        'name.ilike.%$query%,'
        'city.ilike.%$query%,'
        'country.ilike.%$query%,'
        'cuisine.ilike.%$query%',
      );
    }
    if (stars != null) {
      builder = builder.eq('michelin_stars', stars);
    }
    if (countryCode != null) {
      builder = builder.eq('country', countryCode);
    }
    if (category != null) {
      builder = builder.eq('category', category);
    }

    final rows = await builder.order('name');
    return (rows as List)
        .map((row) => Restaurant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Returns the distinct countries present in the catalogue.
  // Used to build dynamic country filter chips.
  Future<List<RestaurantCountry>> getCountries() async {
    final rows = await _client
        .from('restaurants')
        .select('country, country_flag')
        .order('country');

    // Deduplicate by country name.
    final seen = <String>{};
    final result = <RestaurantCountry>[];
    for (final row in rows as List) {
      final name = (row['country'] as String?) ?? '';
      if (name.isNotEmpty && seen.add(name)) {
        result.add(
          RestaurantCountry(
            name: name,
            code:
                name, // used as filter key; matches what search() passes to .eq('country', ...)
            flag: (row['country_flag'] as String?) ?? '',
          ),
        );
      }
    }
    return result;
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
