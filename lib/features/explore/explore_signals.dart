import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cuisine_family.dart';
import '../../models/venue_country.dart';
import 'models/explore_filters.dart';
import 'models/explore_search_results.dart';
import 'models/explore_search_type.dart';

/// One row of `explore_signals` (20261101250000_add_venue_insight_tracking
/// .sql): what Explore's search and filters were used for, as known
/// entities and filter values — never the typed text (decision 1 of
/// docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md, B then A).
@immutable
class ExploreSignal {
  const ExploreSignal(this.signal, [this.dimension, this.value]);

  /// `search_match`, `filter` or `no_results`.
  final String signal;
  final String? dimension;
  final String? value;

  Map<String, Object> toRow(String userId) => {
    'user_id': userId,
    'signal': signal,
    'dimension': ?dimension,
    'value': ?value,
  };

  @override
  bool operator ==(Object other) =>
      other is ExploreSignal &&
      other.signal == signal &&
      other.dimension == dimension &&
      other.value == value;

  @override
  int get hashCode => Object.hash(signal, dimension, value);

  @override
  String toString() => 'ExploreSignal($signal, $dimension, $value)';
}

/// Lower case, accents off, spaces collapsed — so "São Paulo " and
/// "sao paulo" are the same name. Used only to compare, never stored.
String normalizeForMatch(String text) {
  const from = 'àáâãäåāçćčèéêëēěìíîïīñńňòóôõöøōřšśùúûüūůýÿžźż';
  const to = 'aaaaaaaccceeeeeeiiiiinnnooooooorssuuuuuuyyzzz';
  final lower = text.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    if (ch == 'œ') {
      buffer.write('oe');
    } else if (ch == 'ß') {
      buffer.write('ss');
    } else {
      buffer.write(i >= 0 ? to[i] : ch);
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// What a finished search named exactly: a cuisine family, a country, a
/// city or a venue among its results. Exact names only — "Paris" matches
/// the city, "Par" matches nothing — so a match is never a guess about
/// what someone meant. Nothing matched, nothing recorded.
List<ExploreSignal> searchMatches({
  required String query,
  required ExploreSearchResults results,
  required List<CuisineFamily> families,
  required List<VenueCountry> countries,
}) {
  final q = normalizeForMatch(query);
  if (q.length < 2) return const [];
  final out = <ExploreSignal>{};

  for (final family in families) {
    if (normalizeForMatch(family.name) == q || family.slug == q) {
      out.add(ExploreSignal('search_match', 'cuisine_family', family.slug));
    }
  }
  for (final country in countries) {
    if (normalizeForMatch(country.name) == q) {
      out.add(ExploreSignal('search_match', 'country', country.code));
    }
  }
  for (final r in results.restaurants) {
    if (r.cityId != null && normalizeForMatch(r.cityName) == q) {
      out.add(ExploreSignal('search_match', 'city', r.cityId));
    }
    if (normalizeForMatch(r.name) == q) {
      out.add(ExploreSignal('search_match', 'restaurant', r.id));
    }
  }
  for (final h in results.hotels) {
    if (h.cityId != null && normalizeForMatch(h.cityName) == q) {
      out.add(ExploreSignal('search_match', 'city', h.cityId));
    }
    if (normalizeForMatch(h.name) == q) {
      out.add(ExploreSignal('search_match', 'hotel', h.id));
    }
  }
  for (final e in results.events) {
    if (normalizeForMatch(e.name) == q) {
      out.add(ExploreSignal('search_match', 'event', e.id));
    }
  }
  return out.toList();
}

/// The filters in effect, as `filter` dimension/value pairs. "All" and
/// no country are not a choice, so they record nothing.
List<ExploreSignal> activeFilters({
  required ExploreSearchType searchType,
  required String? countryCode,
  required Set<String> cuisineFamilies,
  required RestaurantAwardFilter restaurantAward,
  required HotelKeysFilter hotelKeys,
}) => [
  if (searchType != ExploreSearchType.all)
    ExploreSignal('filter', 'search_type', searchType.name),
  if (countryCode != null) ExploreSignal('filter', 'country', countryCode),
  for (final slug in cuisineFamilies)
    ExploreSignal('filter', 'cuisine_family', slug),
  if (restaurantAward != RestaurantAwardFilter.all)
    ExploreSignal('filter', 'restaurant_award', restaurantAward.name),
  if (hotelKeys != HotelKeysFilter.all)
    ExploreSignal('filter', 'hotel_keys', hotelKeys.name),
];

/// A search that found nothing: what it was filtered on and what its text
/// named, so "French in Lisbon, nothing there" can be counted. With
/// neither, a single row that only says it happened.
List<ExploreSignal> noResults({
  required List<ExploreSignal> filters,
  required List<ExploreSignal> matches,
}) {
  final rows = <ExploreSignal>{
    for (final s in [...filters, ...matches])
      ExploreSignal('no_results', s.dimension, s.value),
  };
  return rows.isEmpty ? const [ExploreSignal('no_results')] : rows.toList();
}

/// Inserts [signals] in one call. Never throws, never awaited.
void sendExploreSignals(List<ExploreSignal> signals) {
  if (signals.isEmpty) return;
  unawaited(_send(signals));
}

Future<void> _send(List<ExploreSignal> signals) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('explore_signals').insert([
      for (final s in signals) s.toRow(userId),
    ]);
  } catch (error) {
    debugPrint('EXPLORE SIGNALS TRACK FAILED: $error');
  }
}
