/// A wine estate — one row of `public.vineyards_full`
/// (20261101550000_add_vineyards.sql). Its own entity, not a kind of venue.
/// Only verified facts live here: name, place, location and The World's 50
/// Best Vineyards rank. An estate's description and photos come from the
/// estate itself after review, so there are none here yet. The rank is
/// drawn in claret, never gold: gold stays reserved for MICHELIN stars
/// and Keys.
class Vineyard {
  final String id;
  final String vineyardCode;
  final String name;
  final String countryCode;
  final String? countryName;
  final String? flagEmoji;

  /// The wine region as the list prints it ("Douro Valley").
  final String? region;

  /// The town or village of the cellar door.
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? websiteUrl;
  final String status;

  /// The current edition of The World's 50 Best Vineyards, when the estate
  /// is on it. Null when it isn't — never a zero.
  final int? worlds50BestYear;
  final int? worlds50BestRank;

  const Vineyard({
    required this.id,
    required this.vineyardCode,
    required this.name,
    required this.countryCode,
    this.countryName,
    this.flagEmoji,
    this.region,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.websiteUrl,
    this.status = 'open',
    this.worlds50BestYear,
    this.worlds50BestRank,
  });

  factory Vineyard.fromMap(Map<String, dynamic> map) => Vineyard(
    id: map['id'] as String,
    vineyardCode: map['vineyard_code'] as String,
    name: map['name'] as String,
    countryCode: map['country_code'] as String,
    countryName: map['country_name'] as String?,
    flagEmoji: map['flag_emoji'] as String?,
    region: map['region'] as String?,
    city: map['city'] as String?,
    address: map['address'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    websiteUrl: map['website_url'] as String?,
    status: map['status'] as String? ?? 'open',
    worlds50BestYear: (map['worlds_50_best_year'] as num?)?.toInt(),
    worlds50BestRank: (map['worlds_50_best_rank'] as num?)?.toInt(),
  );

  bool get isPermanentlyClosed => status == 'permanently_closed';

  /// "Douro Valley, Portugal" — the region when known, then the country.
  String get regionLine => [
    if ((region ?? '').trim().isNotEmpty) region!.trim(),
    if ((countryName ?? '').trim().isNotEmpty) countryName!.trim(),
  ].join(', ');

  /// "Pinhão, Douro Valley" — where the estate is, most specific first.
  /// A region spelled like the town is shown once ("Sauternes", not
  /// "Sauternes, Sauternes").
  String get placeLine {
    final town = (city ?? '').trim();
    final area = (region ?? '').trim();
    return [
      if (town.isNotEmpty) town,
      if (area.isNotEmpty && foldForSearch(area) != foldForSearch(town)) area,
    ].join(', ');
  }

  /// "No. 3 · World's 50 Best Vineyards 2025", or null when unranked.
  /// "🇪🇸  Laguardia, Spain" — the flag, the town (else the region) and
  /// the country's name, never its code. What cards and picker rows show.
  String get cardPlaceLabel {
    final town = [city, region]
        .map((s) => (s ?? '').trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final where = [
      if (town.isNotEmpty) town,
      if ((countryName ?? '').trim().isNotEmpty) countryName!.trim(),
    ].join(', ');
    final flag = (flagEmoji ?? '').trim();
    return [if (flag.isNotEmpty) flag, if (where.isNotEmpty) where].join('  ');
  }

  String? get rankLabel {
    final rank = worlds50BestRank;
    if (rank == null) return null;
    final year = worlds50BestYear;
    return year == null
        ? "No. $rank · World's 50 Best Vineyards"
        : "No. $rank · World's 50 Best Vineyards $year";
  }
}

/// The estates a member's typed producer could be, best first: names that
/// start with what's typed, then names that contain it. A name only
/// proposes; the member picks (never matched on name automatically).
/// Lower-casing plus accent folding, so "chateau" finds "Château".
List<Vineyard> matchingVineyards(
  Iterable<Vineyard> vineyards,
  String typed, {
  int limit = 3,
}) {
  final q = foldForSearch(typed.trim());
  if (q.length < 2) return const [];
  final starts = <Vineyard>[];
  final contains = <Vineyard>[];
  for (final v in vineyards) {
    final name = foldForSearch(v.name);
    if (name.startsWith(q) || name.split(' ').any((w) => w.startsWith(q))) {
      starts.add(v);
    } else if (name.contains(q)) {
      contains.add(v);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

const _accentFolds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', //
};

/// Lower-cased with common Latin accents removed, for matching only.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(_accentFolds[ch] ?? ch);
  }
  return out.toString();
}
