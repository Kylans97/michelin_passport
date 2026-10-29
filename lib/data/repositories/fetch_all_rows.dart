import 'package:supabase_flutter/supabase_flutter.dart';

// PostgREST returns at most `max_rows` rows per request (1000 in
// supabase/config.toml and on production) and says nothing when it cuts a
// response short. A catalogue query without a page loop therefore stops at
// exactly 1000 rows: Guides' MICHELIN catalogue showed "1000 places" once
// production passed 1000 starred restaurants, and the country pickers lost
// every country whose rows fell after row 1000.
//
// [catalogueRowCap] must equal the server's max_rows. A page shorter than it
// is the last one; if the server cap were ever lowered below it, the first
// page would come back short and the loop would stop early, so change both
// together.
const catalogueRowCap = 1000;

/// Every row a query matches, fetched [catalogueRowCap] at a time.
///
/// [query] builds the query fresh for each page and must end in an `.order()`
/// whose last key is unique (`id`): without one, rows that tie on the sort
/// key can move between pages and be skipped or repeated.
Future<List<Map<String, dynamic>>> fetchAllRows(
  PostgrestTransformBuilder<PostgrestList> Function() query,
) async {
  final rows = <Map<String, dynamic>>[];
  while (true) {
    final page = await query().range(
      rows.length,
      rows.length + catalogueRowCap - 1,
    );
    rows.addAll(page);
    if (page.length < catalogueRowCap) return rows;
  }
}
