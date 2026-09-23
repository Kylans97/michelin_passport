/// Builds a PostgREST `or=(...)` ilike filter across [fields] for a
/// free-text [query], or null when there's nothing to filter on — shared by
/// RestaurantRepository.search()/HotelRepository.search()/EventsRepository.
/// loadEvents(query:) so the same query-preparation logic can't drift
/// between them.
///
/// [query] is trimmed before building the pattern. An untrimmed trailing or
/// leading space — routine on iOS, where autocomplete/autocorrect commonly
/// appends one when a word like a city name is confirmed — turns `%query%`
/// into a pattern that requires that literal space in the matched text.
/// name/city_name/country_name never have one, so the untrimmed pattern
/// silently matched nothing: this was the actual cause of a query like
/// "Amsterdam " returning zero results in every Explore mode.
String? buildIlikeOrFilter(String query, List<String> fields) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  return fields.map((field) => '$field.ilike.%$trimmed%').join(',');
}

/// Splits [query] into words and returns one ilike-or-group per word, each
/// checking [fields] independently — for RestaurantRepository.search() and
/// HotelRepository.search() only, so a combined query like "Flore
/// Amsterdam" can match a name and a city on the same row. Callers apply
/// `.or()` once per returned group; PostgREST ANDs repeated `or=` params
/// together (confirmed against the postgrest package source, since
/// postgrest-dart's `.or()` appends to the `or` query parameter rather than
/// overwriting it), so a row must satisfy every word's group — a row with
/// only "Flore" and nothing matching "Amsterdam" anywhere is excluded, not
/// included via a broader OR-across-everything union.
///
/// Deliberately a separate function from [buildIlikeOrFilter] rather than a
/// change to it: five other call sites (events, Gault&Millau, both World's
/// 50 Best repositories) use the single-string form today and didn't ask
/// for AND-across-words semantics — this leaves their behaviour untouched.
///
/// A single-word query returns a single-element list whose one group is
/// byte-for-byte what [buildIlikeOrFilter] would build for the same query
/// and fields — so wiring this in does not change single-word search.
List<String> buildIlikeOrFilters(String query, List<String> fields) {
  final words = query.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            fields.map((field) => '$field.ilike.%$word%').join(','),
      )
      .toList();
}
