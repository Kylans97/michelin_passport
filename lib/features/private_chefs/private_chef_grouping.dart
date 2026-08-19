import '../../models/private_chef.dart';
import '../../models/venue_country.dart';

/// One editorial country section on the Private Chefs landing (Step 2C
/// §3). [countryName] is null only for the (currently unused) group of
/// chefs with no `home_country_code` at all — that group renders with no
/// country heading rather than an empty/placeholder one, see
/// [groupChefsByCountry].
class PrivateChefCountryGroup {
  final String? countryCode;
  final String? countryName;
  final List<PrivateChef> chefs;

  const PrivateChefCountryGroup({
    required this.countryCode,
    required this.countryName,
    required this.chefs,
  });
}

/// Groups [chefs] by `home_country_code` for the landing's editorial
/// country sections. Pure and deterministic — no query, no hardcoded
/// country list, so a second/third/fourth country section appears the
/// moment a published chef with that code exists, without touching this
/// function (Step 2C §3/§16: "must work naturally for future NL/BE/FR/ES
/// ... do not hardcode chef order by Lucas's name").
///
/// Country groups sort alphabetically by resolved name (via
/// [countryNames], falling back to the raw code when unresolved) — stable
/// and never coded to any one country appearing first. Chefs within a
/// group keep the order [chefs] already arrives in — no editorial
/// `display_order` field exists on `private_chefs` yet, so
/// `PrivateChefRepository.getPublishedChefs`'s own `display_name`
/// ascending fallback is preserved here rather than re-sorted, matching
/// this domain's existing "don't invent a ranking field" stance.
List<PrivateChefCountryGroup> groupChefsByCountry(
  List<PrivateChef> chefs,
  Map<String, VenueCountry> countryNames,
) {
  final chefsByCode = <String?, List<PrivateChef>>{};
  for (final chef in chefs) {
    final code = (chef.homeCountryCode ?? '').trim();
    chefsByCode.putIfAbsent(code.isEmpty ? null : code, () => []).add(chef);
  }

  final groups = [
    for (final entry in chefsByCode.entries)
      if (entry.key != null)
        PrivateChefCountryGroup(
          countryCode: entry.key,
          countryName: countryNames[entry.key]?.name ?? entry.key,
          chefs: entry.value,
        ),
  ]..sort((a, b) => a.countryName!.compareTo(b.countryName!));

  final ungrouped = chefsByCode[null];
  if (ungrouped != null) {
    groups.add(
      PrivateChefCountryGroup(
        countryCode: null,
        countryName: null,
        chefs: ungrouped,
      ),
    );
  }
  return groups;
}
