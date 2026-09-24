// Regression guard for a recurring bug class: a column gets added to
// restaurants/hotels (base tables) and to restaurant_repository.dart's/
// hotel_repository.dart's own restaurantFullColumns/hotelFullColumns
// select-list constants, but restaurants_full/hotels_full — which have an
// explicit column list, not `select r.*`/`select h.*` — never get updated
// to expose it. Happened twice: starts_on/ends_on/parent_venue_type/
// parent_venue_id/opening_weekdays (fixed in
// 20260918120000_fix_missing_popup_columns_on_full_views.sql), then
// missing_listing_report_id (fixed in
// 20260924150000_add_missing_listing_report_id_to_full_views.sql, after it
// broke Explore and Profile in build 1.0.0+8).
//
// This test imports the constants directly rather than retyping them, so
// it can never itself drift from what the repositories actually select,
// and runs them as real PostgREST queries against the live views. A column
// present on the table but missing from the view fails here with a 42703
// from Postgres — before it ever reaches a build.
//
// Deliberately NOT hermetic like the rest of this suite (see
// friend_profile_screen_navigation_test.dart's MockClient) — it needs real
// network and a real .env, because the live view definition is the only
// thing that actually exposes this bug class. Read-only (LIMIT 1, no
// writes), uses the same anon key already public inside the shipped app.
// Skips itself, rather than failing, only when no .env is present at all
// (e.g. a clean checkout with no credentials) — a network error with .env
// present is a real failure, not a skip: if this can't reach Supabase, it
// can't verify anything, and that's itself worth stopping a build for.
//
// Run this (`flutter test test/live_view_full_columns_test.dart`) with
// network up before every build — it does not run in CI without secrets.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:michelin_passport/data/repositories/hotel_repository.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';

Map<String, String> _loadEnv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final i = trimmed.indexOf('=');
    if (i == -1) continue;
    env[trimmed.substring(0, i)] = trimmed.substring(i + 1);
  }
  return env;
}

Future<void> _expectViewSelects({
  required String baseUrl,
  required String anonKey,
  required String view,
  required String columns,
}) async {
  final uri = Uri.parse(
    '$baseUrl/rest/v1/$view',
  ).replace(queryParameters: {'select': columns, 'limit': '1'});
  final response = await http.get(
    uri,
    headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
  );
  if (response.statusCode != 200) {
    fail(
      'Querying $view with the literal Dart column list failed '
      '(${response.statusCode}): ${response.body}\n'
      'A column in that list exists in Dart but is not exposed by the '
      '$view view — add it to the view\'s CREATE OR REPLACE VIEW (see '
      '20260924150000_add_missing_listing_report_id_to_full_views.sql '
      'for the pattern).',
    );
  }
}

void main() {
  final env = _loadEnv();
  final url = env['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'];
  final noEnv = url == null || anonKey == null;
  const skipReason = 'no .env found — run with network + credentials '
      'before a build';

  group('live view columns (requires network + .env)', () {
    test('restaurantFullColumns resolves against restaurants_full', () async {
      await _expectViewSelects(
        baseUrl: url!,
        anonKey: anonKey!,
        view: 'restaurants_full',
        columns: restaurantFullColumns,
      );
    }, skip: noEnv ? skipReason : false);

    test('hotelFullColumns resolves against hotels_full', () async {
      await _expectViewSelects(
        baseUrl: url!,
        anonKey: anonKey!,
        view: 'hotels_full',
        columns: hotelFullColumns,
      );
    }, skip: noEnv ? skipReason : false);
  });
}
