import '../../models/venue_country.dart';

/// "City, Country" for a chef's discovery card and Detail hero (Step 2C
/// §12) — prefers a full, user-facing country name (e.g. "Breda,
/// Netherlands") resolved from [countryNames] (see
/// `PrivateChefRepository.getCountryNames`), falling back to the raw ISO
/// code only when the countries table has no match for it. Never leaves a
/// dangling ", " when one half is missing — city-only and country-only
/// both render as a single clean value.
String? formatChefLocation({
  required String? city,
  required String? countryCode,
  required Map<String, VenueCountry> countryNames,
}) {
  final trimmedCity = (city ?? '').trim();
  final trimmedCode = (countryCode ?? '').trim();
  final countryText = trimmedCode.isEmpty
      ? ''
      : (countryNames[trimmedCode]?.name ?? trimmedCode);
  final parts = [
    if (trimmedCity.isNotEmpty) trimmedCity,
    if (countryText.isNotEmpty) countryText,
  ];
  return parts.isEmpty ? null : parts.join(', ');
}
