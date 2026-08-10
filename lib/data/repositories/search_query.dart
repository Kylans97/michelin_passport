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
