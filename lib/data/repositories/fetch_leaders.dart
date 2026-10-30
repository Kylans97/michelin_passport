import 'package:supabase_flutter/supabase_flutter.dart';

import 'fetch_all_rows.dart';

/// The rows that can make the top [limit] of a ranking by [primaryKey]
/// (descending, nulls last) then [secondaryKey] (ascending, nulls last) —
/// at most a page or two, instead of the whole catalogue.
///
/// Explore's Worth the Journey/Stay a Little Longer used to download every
/// restaurant and hotel (about 1 MB gzipped per mount, measured 2026-10-30)
/// to show eight of each. The server sorts on the two integer keys alone;
/// the final name tie-break stays client-side, in the existing selector, so
/// a difference between Postgres' collation and Dart's String.compareTo can
/// never change which venues appear. That is why the result is a candidate
/// set, not the answer: when the rows tied with the [limit]th one run past
/// it, the whole tie group comes back, and the caller's selector picks.
///
/// [select] builds `client.from(view).select(columns)` fresh for each
/// request; its columns must include both keys and `id`.
Future<List<Map<String, dynamic>>> fetchLeaderCandidates({
  required PostgrestFilterBuilder<PostgrestList> Function() select,
  required String primaryKey,
  required String secondaryKey,
  required int limit,
}) async {
  final head = await select()
      .order(primaryKey, ascending: false, nullsFirst: false)
      .order(secondaryKey, ascending: true, nullsFirst: false)
      .order('id', ascending: true)
      .limit(limit + 1);
  if (head.length <= limit) return head;

  final boundary = head[limit - 1];
  bool tiedWithBoundary(Map<String, dynamic> row) =>
      row[primaryKey] == boundary[primaryKey] &&
      row[secondaryKey] == boundary[secondaryKey];
  if (!tiedWithBoundary(head[limit])) return head.sublist(0, limit);

  // Every row ranked strictly above the boundary is already in [head]; the
  // tie group can be large (on 2026-10-30, 133 of 162 three-star restaurants
  // shared a null rank), so it is paged like any catalogue read.
  final ties = await fetchAllRows(() {
    var query = select();
    for (final key in [primaryKey, secondaryKey]) {
      final value = boundary[key];
      query = value == null
          ? query.isFilter(key, null)
          : query.eq(key, value as Object);
    }
    return query.order('id', ascending: true);
  });
  return [...head.where((row) => !tiedWithBoundary(row)), ...ties];
}
