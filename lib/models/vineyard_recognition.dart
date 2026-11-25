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

/// A classification list as Guides shows it: the row label, the line under
/// it, and the heading of its own estate list. Fixed order; a scheme the app
/// does not know yet is never shown under a raw code.
class RecognitionScheme {
  final String code;
  final String label;
  final String descriptor;

  const RecognitionScheme(this.code, this.label, this.descriptor);
}

const bordeauxClassifications = <RecognitionScheme>[
  RecognitionScheme(
    'bordeaux_1855_medoc',
    '1855, Médoc',
    'The 1855 classification of the red wines of the Médoc and Graves.',
  ),
  RecognitionScheme(
    'bordeaux_1855_sauternes',
    '1855, Sauternes and Barsac',
    'The 1855 classification of the sweet wines.',
  ),
  RecognitionScheme(
    'graves_1959',
    'Graves',
    'The classified growths of the Graves.',
  ),
  RecognitionScheme(
    'saint_emilion',
    'Saint-Émilion',
    'The Saint-Émilion classification of 2022.',
  ),
];

/// One estate in a list: the big claret [marker] (the 50 Best rank, or
/// empty) and an optional [note] under where it is (the class).
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

/// The estates of one classification, highest class first, then by name,
/// each with its class as printed (product owner, 2026-11-25: a Guides card
/// with one row per list). An estate the app could not load is left out.
List<EstateCollectionEntry> classifiedEstates({
  required String scheme,
  required List<VineyardRecognition> recognitions,
  required Map<String, Vineyard> byId,
}) {
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
  return [
    for (final r in rows)
      EstateCollectionEntry(vineyard: byId[r.vineyardId]!, note: r.classLabel),
  ];
}
