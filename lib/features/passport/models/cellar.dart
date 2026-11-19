import '../../../data/repositories/visit_wine_repository.dart';
import '../../../models/vineyard.dart';

/// One estate in the Cellar and the member's wines from it, newest first.
class CellarEstate {
  final Vineyard vineyard;
  final List<CellarWine> wines;

  const CellarEstate({required this.vineyard, required this.wines});
}

/// One wine region in the Cellar: "Douro Valley", or the country when the
/// estate has no region.
class CellarRegion {
  final String label;
  final List<CellarEstate> estates;

  const CellarRegion({required this.label, required this.estates});

  int get wineCount => estates.fold(0, (sum, e) => sum + e.wines.length);
}

/// The Passport's Cellar: the member's wines grouped by region and estate,
/// and the ones not linked to an estate kept apart, exactly as written.
class Cellar {
  final List<CellarRegion> regions;
  final List<CellarWine> unlinked;

  const Cellar({required this.regions, required this.unlinked});

  int get wineCount =>
      unlinked.length + regions.fold(0, (sum, r) => sum + r.wineCount);
  int get estateCount => regions.fold(0, (sum, r) => sum + r.estates.length);
  int get regionCount => regions.length;
  bool get isEmpty => regions.isEmpty && unlinked.isEmpty;
}

/// Groups [wines] (newest first) into a [Cellar]. Only a wine the member
/// linked to an estate is grouped; everything else stays in [Cellar.unlinked]
/// in its own order. Regions and estates with the most wines come first,
/// then alphabetically. Grouping keys on the estate's id and on region plus
/// country — never on a producer's name.
Cellar buildCellar(List<CellarWine> wines) {
  final unlinked = <CellarWine>[];
  final byEstate = <String, List<CellarWine>>{};
  final estates = <String, Vineyard>{};
  for (final w in wines) {
    final vineyard = w.wine.vineyard;
    if (vineyard == null) {
      unlinked.add(w);
      continue;
    }
    estates[vineyard.id] = vineyard;
    byEstate.putIfAbsent(vineyard.id, () => []).add(w);
  }

  final byRegion = <String, List<CellarEstate>>{};
  final labels = <String, String>{};
  for (final entry in byEstate.entries) {
    final vineyard = estates[entry.key]!;
    final region = (vineyard.region ?? '').trim();
    final country = (vineyard.countryName ?? vineyard.countryCode).trim();
    final key = '$region|${vineyard.countryCode}';
    labels[key] = region.isEmpty ? country : region;
    byRegion
        .putIfAbsent(key, () => [])
        .add(CellarEstate(vineyard: vineyard, wines: entry.value));
  }

  int byCountThenName(int countA, int countB, String a, String b) {
    final byCount = countB.compareTo(countA);
    return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
  }

  final regions =
      [
        for (final entry in byRegion.entries)
          CellarRegion(
            label: labels[entry.key]!,
            estates: entry.value
              ..sort(
                (a, b) => byCountThenName(
                  a.wines.length,
                  b.wines.length,
                  a.vineyard.name,
                  b.vineyard.name,
                ),
              ),
          ),
      ]..sort(
        (a, b) => byCountThenName(a.wineCount, b.wineCount, a.label, b.label),
      );

  return Cellar(regions: regions, unlinked: unlinked);
}
