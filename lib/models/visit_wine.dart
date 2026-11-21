import 'vineyard.dart';

/// `visit_wines.bottle_size` (20261101330000).
enum WineSize {
  glass('glass', 'Glass'),
  half('half', 'Half'),
  bottle('bottle', 'Bottle'),
  magnum('magnum', 'Magnum'),
  other('other', 'Other');

  const WineSize(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static WineSize? fromDb(String? value) {
    for (final size in values) {
      if (size.dbValue == value) return size;
    }
    return null;
  }
}

/// What the member thought of a wine (`verdict`, 20261101640000). Three
/// plain answers, never a score; a verdict never makes a stamp.
enum WineVerdict {
  again('again', 'Would drink again'),
  fine('fine', 'It was fine'),
  notForMe('not_for_me', 'Not for me');

  const WineVerdict(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static WineVerdict? fromDb(String? value) {
    for (final verdict in values) {
      if (verdict.dbValue == value) return verdict;
    }
    return null;
  }
}

/// Where a wine kept without a visit was drunk (`cellar_wines.setting`,
/// 20261101640000).
enum WineSetting {
  home('home', 'At home'),
  estate('estate', 'At an estate'),
  elsewhere('elsewhere', 'Somewhere else');

  const WineSetting(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static WineSetting? fromDb(String? value) {
    for (final setting in values) {
      if (setting.dbValue == value) return setting;
    }
    return null;
  }
}

/// One wine noted on a visit or stay, or kept in the Cellar without one.
/// Every field is optional. [vintage] null with [nonVintage] false means
/// the year wasn't noted; [nonVintage] means the wine has none, like NV
/// Champagne.
class VisitWine {
  final String? id;
  final String? producer;
  final String? wineName;
  final int? vintage;
  final bool nonVintage;
  final WineSize? size;

  /// The estate the member picked for [producer] (`visit_wines.vineyard_id`,
  /// 20261101550000). Null for a producer kept as written, and for every
  /// wine logged before estates existed — those are never linked by name.
  final String? vineyardId;

  /// The picked estate itself, when it was read along with the wine.
  final Vineyard? vineyard;

  /// What the member thought of it, and one line to remember it by.
  final WineVerdict? verdict;
  final String? tastingNote;

  /// Only for a wine kept without a visit (`cellar_wines`): where and when
  /// it was drunk. Null on a visit's wine.
  final WineSetting? setting;
  final String? place;
  final DateTime? drunkOn;

  const VisitWine({
    this.id,
    this.producer,
    this.wineName,
    this.vintage,
    this.nonVintage = false,
    this.size,
    this.vineyardId,
    this.vineyard,
    this.verdict,
    this.tastingNote,
    this.setting,
    this.place,
    this.drunkOn,
  });

  factory VisitWine.fromJson(Map<String, dynamic> json) => VisitWine(
    id: json['id'] as String?,
    producer: json['producer'] as String?,
    wineName: json['wine_name'] as String?,
    vintage: (json['vintage'] as num?)?.toInt(),
    nonVintage: json['non_vintage'] as bool? ?? false,
    size: WineSize.fromDb(json['bottle_size'] as String?),
    vineyardId: json['vineyard_id'] as String?,
    vineyard: _embeddedVineyard(json['vineyards']),
    verdict: WineVerdict.fromDb(json['verdict'] as String?),
    tastingNote: json['tasting_note'] as String?,
    setting: WineSetting.fromDb(json['setting'] as String?),
    place: json['place'] as String?,
    drunkOn: switch (json['drunk_on']) {
      final String day => DateTime.tryParse(day),
      _ => null,
    },
  );

  /// The row to write to `visit_wines`. `vineyard_id` is only sent when
  /// there is a link to write or to clear ([withVineyard]), and the verdict
  /// and note only when there is one to write or to clear ([withVerdict]),
  /// so saving a plain wine still works against a database without those
  /// columns (before 20261101550000 and 20261101640000).
  Map<String, Object?> toRow({
    bool withVineyard = false,
    bool withVerdict = false,
  }) => {
    'producer': producer,
    'wine_name': wineName,
    'vintage': vintage,
    'non_vintage': nonVintage,
    'bottle_size': size?.dbValue,
    if (withVineyard || vineyardId != null) 'vineyard_id': vineyardId,
    if (withVerdict || verdict != null || tastingNote != null) ...{
      'verdict': verdict?.dbValue,
      'tasting_note': tastingNote,
    },
  };

  /// The row to write to `cellar_wines`: every column, since that table
  /// only exists with all of them.
  Map<String, Object?> toCellarRow() => {
    'producer': producer,
    'wine_name': wineName,
    'vintage': vintage,
    'non_vintage': nonVintage,
    'bottle_size': size?.dbValue,
    'vineyard_id': vineyardId,
    'verdict': verdict?.dbValue,
    'tasting_note': tastingNote,
    'setting': (setting ?? WineSetting.home).dbValue,
    'place': place,
    'drunk_on': drunkOn == null ? null : _day(drunkOn!),
  };

  VisitWine copyWith({String? id}) => VisitWine(
    id: id ?? this.id,
    producer: producer,
    wineName: wineName,
    vintage: vintage,
    nonVintage: nonVintage,
    size: size,
    vineyardId: vineyardId,
    vineyard: vineyard,
    verdict: verdict,
    tastingNote: tastingNote,
    setting: setting,
    place: place,
    drunkOn: drunkOn,
  );

  /// The verdict the Cellar's filter keeps.
  bool get wouldDrinkAgain => verdict == WineVerdict.again;

  /// The database refuses a row that says nothing.
  bool get isEmpty =>
      producer == null &&
      wineName == null &&
      vintage == null &&
      !nonVintage &&
      size == null;

  /// The year as shown: the vintage, "NV", or null when it wasn't noted.
  String? get yearLabel => vintage?.toString() ?? (nonVintage ? 'NV' : null);

  /// The main line: the wine, else the producer, else the size.
  String get title => wineName ?? producer ?? size?.label ?? '';

  /// What's left for the line under [title].
  String? get subtitle {
    final kept = setting;
    final parts = [
      if (wineName != null && producer != null) producer!,
      if ((wineName != null || producer != null) && size != null) size!.label,
      // A wine kept without a visit says where it was drunk.
      if (kept != null) place ?? kept.label,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The `vineyards(...)` embed on a wine row: the estate, its region and its
/// country's name, enough to group a cellar without another query.
Vineyard? _embeddedVineyard(Object? embed) {
  if (embed is! Map<String, dynamic>) return null;
  final country = embed['countries'];
  return Vineyard(
    id: embed['id'] as String,
    vineyardCode: embed['vineyard_code'] as String,
    name: embed['name'] as String,
    countryCode: embed['country_code'] as String,
    countryName: country is Map<String, dynamic>
        ? country['name'] as String?
        : null,
    region: embed['region'] as String?,
    city: embed['city'] as String?,
  );
}

/// A year a member can type: four digits, not impossible. Null is fine,
/// the field is optional.
bool isValidWineYear(int? year, {DateTime? now}) {
  if (year == null) return true;
  return year >= 1800 && year <= (now ?? DateTime.now()).year + 1;
}

/// Up to [limit] of [known] matching what's typed so far, without an exact
/// match (nothing left to complete). Case and accent differences aside only
/// by lower-casing: these are the member's own spellings.
List<String> matchingWineNames(
  Iterable<String> known,
  String typed, {
  int limit = 3,
}) {
  final q = typed.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final name in known) {
    final lower = name.toLowerCase();
    if (lower == q || !lower.contains(q) || !seen.add(lower)) continue;
    out.add(name);
    if (out.length == limit) break;
  }
  return out;
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
