import 'vineyard.dart';

/// One official classification of an estate: a row of
/// `public.vineyard_recognitions` (20261101770000). The class is printed as
/// the official list prints it; [classOrder] sorts within a list (1 is the
/// highest), so nothing here parses the printed class. Never gold.
class VineyardRecognition {
  final String vineyardId;
  final String scheme;
  final String classLabel;
  final int classOrder;
  final int edition;

  const VineyardRecognition({
    required this.vineyardId,
    required this.scheme,
    required this.classLabel,
    required this.classOrder,
    required this.edition,
  });

  factory VineyardRecognition.fromMap(Map<String, dynamic> map) =>
      VineyardRecognition(
        vineyardId: map['vineyard_id'] as String,
        scheme: map['scheme'] as String,
        classLabel: map['class'] as String,
        classOrder: (map['class_order'] as num).toInt(),
        edition: (map['edition'] as num).toInt(),
      );
}

/// The lists the Wine Estates collection shows after the 50 Best, in this
/// order, with the heading each gets. A scheme the app does not know yet is
/// left out rather than shown under a raw code.
const recognitionSchemeTitles = <String, String>{
  'bordeaux_1855_medoc': 'Bordeaux 1855, Médoc',
  'bordeaux_1855_sauternes': 'Bordeaux 1855, Sauternes and Barsac',
  'graves_1959': 'Graves',
  'saint_emilion': 'Saint-Émilion',
};

/// One estate in a collection section: the big claret [marker] (the 50 Best
/// rank, or empty) and an optional [note] under where it is (the class).
class EstateCollectionEntry {
  final Vineyard vineyard;
  final String marker;
  final String? note;

  const EstateCollectionEntry({
    required this.vineyard,
    this.marker = '',
    this.note,
  });
}

class EstateCollectionSection {
  final String title;
  final List<EstateCollectionEntry> entries;

  const EstateCollectionSection({required this.title, required this.entries});
}

/// The Wine Estates collection, one section per list (product owner,
/// 2026-11-25: "One section per list"): The World's 50 Best Vineyards in
/// rank order first, then each official classification in its own class
/// order, then by name. An estate on several lists appears in each.
/// [byId] resolves the classified estates; one it cannot resolve is left
/// out. Empty sections are left out.
List<EstateCollectionSection> buildEstateCollection({
  required List<Vineyard> ranked,
  required List<VineyardRecognition> recognitions,
  required Map<String, Vineyard> byId,
}) {
  final sections = <EstateCollectionSection>[];
  final rankedSorted = ranked.where((v) => v.worlds50BestRank != null).toList()
    ..sort((a, b) => a.worlds50BestRank!.compareTo(b.worlds50BestRank!));
  if (rankedSorted.isNotEmpty) {
    final years = {for (final v in rankedSorted) ?v.worlds50BestYear};
    sections.add(
      EstateCollectionSection(
        title: years.length == 1
            ? "The World's 50 Best Vineyards ${years.single}"
            : "The World's 50 Best Vineyards",
        entries: [
          for (final v in rankedSorted)
            EstateCollectionEntry(vineyard: v, marker: '${v.worlds50BestRank}'),
        ],
      ),
    );
  }
  for (final scheme in recognitionSchemeTitles.keys) {
    final rows =
        recognitions
            .where((r) => r.scheme == scheme && byId.containsKey(r.vineyardId))
            .toList()
          ..sort((a, b) {
            final byClass = a.classOrder.compareTo(b.classOrder);
            if (byClass != 0) return byClass;
            return foldForSearch(
              byId[a.vineyardId]!.name,
            ).compareTo(foldForSearch(byId[b.vineyardId]!.name));
          });
    if (rows.isEmpty) continue;
    sections.add(
      EstateCollectionSection(
        title: recognitionSchemeTitles[scheme]!,
        entries: [
          for (final r in rows)
            EstateCollectionEntry(
              vineyard: byId[r.vineyardId]!,
              note: r.classLabel,
            ),
        ],
      ),
    );
  }
  return sections;
}
