import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_country.dart';

/// Resolves [presentCodes] (the distinct country_code values found in one
/// catalogue) against the public.countries reference table — one query,
/// shared by RestaurantRepository.getCountries() and
/// HotelRepository.getCountries() so the countries-join logic isn't
/// duplicated per catalogue. Each repository still runs its own query to
/// find which codes are actually present in its own catalogue first.
Future<List<VenueCountry>> resolveVenueCountries(
  SupabaseClient client,
  Set<String> presentCodes,
) async {
  if (presentCodes.isEmpty) return [];
  final countryRows = await client
      .from('countries')
      .select('country_code, name, flag_emoji')
      .order('name');
  return [
    for (final row in countryRows as List)
      if (presentCodes.contains(row['country_code'] as String?))
        VenueCountry(
          name: (row['name'] as String?) ?? '',
          code: (row['country_code'] as String?) ?? '',
          flag: (row['flag_emoji'] as String?) ?? '',
        ),
  ];
}
