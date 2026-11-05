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

/// One wine noted on a visit or stay. Every field is optional. [vintage]
/// null with [nonVintage] false means the year wasn't noted; [nonVintage]
/// means the wine has none, like NV Champagne.
class VisitWine {
  final String? id;
  final String? producer;
  final String? wineName;
  final int? vintage;
  final bool nonVintage;
  final WineSize? size;

  const VisitWine({
    this.id,
    this.producer,
    this.wineName,
    this.vintage,
    this.nonVintage = false,
    this.size,
  });

  factory VisitWine.fromJson(Map<String, dynamic> json) => VisitWine(
    id: json['id'] as String?,
    producer: json['producer'] as String?,
    wineName: json['wine_name'] as String?,
    vintage: (json['vintage'] as num?)?.toInt(),
    nonVintage: json['non_vintage'] as bool? ?? false,
    size: WineSize.fromDb(json['bottle_size'] as String?),
  );

  Map<String, Object?> toRow() => {
    'producer': producer,
    'wine_name': wineName,
    'vintage': vintage,
    'non_vintage': nonVintage,
    'bottle_size': size?.dbValue,
  };

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
    final parts = [
      if (wineName != null && producer != null) producer!,
      if ((wineName != null || producer != null) && size != null) size!.label,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
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
