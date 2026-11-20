import 'vineyard.dart' show foldForSearch;

/// A wine region on the globe's wine layer (`public.wine_regions`,
/// 20261101580000). Editorial reference content: drawn as a soft patch
/// around [latitude]/[longitude] reaching about [radiusKm], never as a
/// border.
class WineRegion {
  final String id;
  final String code;
  final String name;
  final List<String> aliases;
  final String countryCode;
  final String? countryName;
  final String? parentId;
  final double latitude;
  final double longitude;
  final int radiusKm;
  final String summary;

  /// "A red from here, in the glass", 1–5; null for a white or sparkling
  /// region.
  final int? redBody;
  final int? redAcidity;
  final int? redTannin;
  final String? pairing;
  final String? labelNote;

  /// The region's shape (20261101590000): polygons, each a list of rings
  /// (outer first, then holes), each ring (longitude, latitude) pairs —
  /// the union of the municipalities in its official specification. Empty
  /// when there is no outline yet; the globe then draws a patch around
  /// [latitude]/[longitude].
  final List<List<List<(double, double)>>> outline;

  const WineRegion({
    required this.id,
    required this.code,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.summary,
    this.aliases = const [],
    this.countryName,
    this.parentId,
    this.radiusKm = 40,
    this.redBody,
    this.redAcidity,
    this.redTannin,
    this.pairing,
    this.labelNote,
    this.outline = const [],
  });

  factory WineRegion.fromMap(Map<String, dynamic> map) => WineRegion(
    id: map['id'] as String,
    code: map['region_code'] as String,
    name: map['name'] as String,
    aliases: _strings(map['aliases']),
    countryCode: map['country_code'] as String,
    countryName: (map['countries'] as Map?)?['name'] as String?,
    parentId: map['parent_id'] as String?,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    radiusKm: (map['radius_km'] as num?)?.toInt() ?? 40,
    summary: map['summary'] as String,
    redBody: (map['red_body'] as num?)?.toInt(),
    redAcidity: (map['red_acidity'] as num?)?.toInt(),
    redTannin: (map['red_tannin'] as num?)?.toInt(),
    pairing: map['pairing'] as String?,
    labelNote: map['label_note'] as String?,
    outline: _outline(map['outline']),
  );

  bool get hasRedProfile =>
      redBody != null && redAcidity != null && redTannin != null;
}

enum GrapeColour {
  red,
  white;

  static GrapeColour fromDb(String? value) =>
      value == 'white' ? GrapeColour.white : GrapeColour.red;

  String get label => this == GrapeColour.red ? 'Red' : 'White';
}

class Grape {
  final String id;
  final String code;
  final String name;
  final List<String> aliases;
  final GrapeColour colour;
  final String summary;
  final List<String> tastes;
  final String? agedNote;
  final int? body;
  final int? acidity;
  final int? tannin;
  final String? similarGrapeId;
  final String? similarNote;

  const Grape({
    required this.id,
    required this.code,
    required this.name,
    required this.colour,
    required this.summary,
    this.aliases = const [],
    this.tastes = const [],
    this.agedNote,
    this.body,
    this.acidity,
    this.tannin,
    this.similarGrapeId,
    this.similarNote,
  });

  factory Grape.fromMap(Map<String, dynamic> map) => Grape(
    id: map['id'] as String,
    code: map['grape_code'] as String,
    name: map['name'] as String,
    aliases: _strings(map['aliases']),
    colour: GrapeColour.fromDb(map['colour'] as String?),
    summary: map['summary'] as String,
    tastes: _strings(map['tastes']),
    agedNote: map['aged_note'] as String?,
    body: (map['body'] as num?)?.toInt(),
    acidity: (map['acidity'] as num?)?.toInt(),
    tannin: (map['tannin'] as num?)?.toInt(),
    similarGrapeId: map['similar_grape_id'] as String?,
    similarNote: map['similar_note'] as String?,
  );
}

/// A grape a region is known for, and what it becomes there.
class RegionGrape {
  final String regionId;
  final String grapeId;
  final String? localNote;
  final int order;

  const RegionGrape({
    required this.regionId,
    required this.grapeId,
    this.localNote,
    this.order = 0,
  });

  factory RegionGrape.fromMap(Map<String, dynamic> map) => RegionGrape(
    regionId: map['region_id'] as String,
    grapeId: map['grape_id'] as String,
    localNote: map['local_note'] as String?,
    order: (map['display_order'] as num?)?.toInt() ?? 0,
  );
}

/// A name as it appears on a wine list — Chablis, Barolo — and its region.
class WineAppellation {
  final String id;
  final String name;
  final List<String> aliases;
  final String regionId;

  /// red, white, rose, sparkling or mixed.
  final String colour;
  final String note;
  final int order;

  const WineAppellation({
    required this.id,
    required this.name,
    required this.regionId,
    required this.colour,
    required this.note,
    this.aliases = const [],
    this.order = 0,
  });

  factory WineAppellation.fromMap(Map<String, dynamic> map) => WineAppellation(
    id: map['id'] as String,
    name: map['name'] as String,
    aliases: _strings(map['aliases']),
    regionId: map['region_id'] as String,
    colour: map['colour'] as String,
    note: map['note'] as String,
    order: (map['display_order'] as num?)?.toInt() ?? 0,
  );

  String get colourLabel => switch (colour) {
    'white' => 'white',
    'rose' => 'rosé',
    'sparkling' => 'sparkling',
    'mixed' => 'red and white',
    _ => 'red',
  };
}

/// One thing a wine-list search can find.
sealed class WineSearchHit {
  const WineSearchHit();
}

class RegionHit extends WineSearchHit {
  final WineRegion region;
  const RegionHit(this.region);
}

class AppellationHit extends WineSearchHit {
  final WineAppellation appellation;
  final WineRegion region;
  const AppellationHit(this.appellation, this.region);
}

class GrapeHit extends WineSearchHit {
  final Grape grape;
  const GrapeHit(this.grape);
}

/// Everything published for the wine layer, loaded at once (a few dozen
/// rows) and searched on the device.
class WineAtlas {
  final List<WineRegion> regions;
  final List<Grape> grapes;
  final List<RegionGrape> regionGrapes;
  final List<WineAppellation> appellations;

  WineAtlas({
    required this.regions,
    required this.grapes,
    required this.regionGrapes,
    required this.appellations,
  }) : _regionById = {for (final r in regions) r.id: r},
       _grapeById = {for (final g in grapes) g.id: g};

  static final empty = WineAtlas(
    regions: const [],
    grapes: const [],
    regionGrapes: const [],
    appellations: const [],
  );

  final Map<String, WineRegion> _regionById;
  final Map<String, Grape> _grapeById;

  bool get isEmpty => regions.isEmpty;

  WineRegion? region(String id) => _regionById[id];
  Grape? grape(String? id) => id == null ? null : _grapeById[id];

  /// The regions drawn on the globe: top-level ones only.
  List<WineRegion> get globeRegions => [
    for (final r in regions)
      if (r.parentId == null) r,
  ];

  /// The grapes [region] is known for, in order, with what each becomes
  /// there.
  List<(Grape, String?)> grapesOf(WineRegion region) {
    final links = [
      for (final l in regionGrapes)
        if (l.regionId == region.id) l,
    ]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final l in links)
        if (_grapeById[l.grapeId] != null)
          (_grapeById[l.grapeId]!, l.localNote),
    ];
  }

  /// The regions where [grape] grows, with what it becomes in each.
  List<(WineRegion, String?)> regionsOf(Grape grape) => [
    for (final l in regionGrapes)
      if (l.grapeId == grape.id && _regionById[l.regionId] != null)
        (_regionById[l.regionId]!, l.localNote),
  ];

  List<WineAppellation> appellationsOf(WineRegion region) => [
    for (final a in appellations)
      if (a.regionId == region.id) a,
  ]..sort((a, b) => a.order.compareTo(b.order));

  /// What a wine list says, matched against stored names and aliases only,
  /// accents folded. Names that start with what was typed come first, then
  /// names that contain it; regions, then list names, then grapes.
  List<WineSearchHit> search(String typed, {int limit = 12}) {
    final q = foldForSearch(typed.trim());
    if (q.length < 2) return const [];
    int rank(String name, List<String> aliases) {
      var best = 3;
      for (final n in [name, ...aliases]) {
        final f = foldForSearch(n);
        if (f.startsWith(q) ||
            f.split(RegExp(r'[\s-]')).any((w) => w.startsWith(q))) {
          best = best < 1 ? best : 1;
        } else if (f.contains(q)) {
          best = best < 2 ? best : 2;
        }
      }
      return best;
    }

    final scored = <(int, int, WineSearchHit)>[];
    for (final r in regions) {
      final s = rank(r.name, r.aliases);
      if (s < 3) scored.add((s, 0, RegionHit(r)));
    }
    for (final a in appellations) {
      final region = _regionById[a.regionId];
      if (region == null) continue;
      final s = rank(a.name, a.aliases);
      if (s < 3) scored.add((s, 1, AppellationHit(a, region)));
    }
    for (final g in grapes) {
      final s = rank(g.name, g.aliases);
      if (s < 3) scored.add((s, 2, GrapeHit(g)));
    }
    scored.sort((a, b) {
      final byScore = a.$1.compareTo(b.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return [for (final s in scored.take(limit)) s.$3];
  }
}

/// Reads the stored polygons; anything malformed reads as no outline
/// rather than a broken shape.
List<List<List<(double, double)>>> _outline(Object? value) {
  if (value is! List) return const [];
  try {
    return [
      for (final polygon in value)
        [
          for (final ring in polygon as List)
            [
              for (final point in ring as List)
                (
                  ((point as List)[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ),
            ],
        ],
    ];
  } catch (_) {
    return const [];
  }
}

List<String> _strings(Object? value) => [
  for (final v in (value as List?) ?? const []) v as String,
];
