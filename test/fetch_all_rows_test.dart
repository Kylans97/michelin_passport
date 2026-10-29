// PostgREST caps every response at max_rows (1000) without saying so.
// Guides' MICHELIN catalogue showed "1000 places" on 2026-10-29 while
// production held 1797 starred restaurants, because RestaurantRepository.
// search() read the catalogue in one request. fetchAllRows pages past the
// cap; asserted here against a fake server that caps responses the same way.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/fetch_all_rows.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';

void main() {
  late List<Uri> requests;

  // A fake restaurants_full of [total] rows, honouring offset/limit and
  // capping each response at catalogueRowCap, as PostgREST does.
  SupabaseClient clientWith(
    int total, {
    String Function(int i)? countryOf,
  }) {
    requests = [];
    return SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.endsWith('/countries')) {
          return http.Response(
            jsonEncode([
              for (final c in ['DE', 'FR', 'NL'])
                {'country_code': c, 'name': c, 'flag_emoji': null},
            ]),
            200,
            request: request,
          );
        }
        if (!request.url.path.endsWith('/restaurants_full')) {
          return http.Response('[]', 200, request: request);
        }
        final q = request.url.queryParameters;
        final offset = int.parse(q['offset'] ?? '0');
        final limit = int.parse(q['limit'] ?? '$total');
        final end = [
          total,
          offset + limit,
          offset + catalogueRowCap,
        ].reduce((a, b) => a < b ? a : b);
        final rows = [
          for (var i = offset; i < end; i++)
            {'id': 'r$i', 'country_code': countryOf?.call(i) ?? 'NL'},
        ];
        return http.Response(jsonEncode(rows), 200, request: request);
      }),
    );
  }

  List<Uri> catalogueRequests() => [
    for (final u in requests)
      if (u.path.endsWith('/restaurants_full')) u,
  ];

  PostgrestTransformBuilder<PostgrestList> Function() catalogue(
    SupabaseClient client,
  ) =>
      () => client
          .from('restaurants_full')
          .select('id')
          .order('id', ascending: true);

  test('returns every row past the cap, in pages of 1000', () async {
    final client = clientWith(1797);
    final rows = await fetchAllRows(catalogue(client));
    expect(rows, hasLength(1797));
    expect(rows.map((r) => r['id']).toSet(), hasLength(1797));
    expect(catalogueRequests(), hasLength(2));
    expect(catalogueRequests().map((u) => u.queryParameters['offset']), [
      '0',
      '1000',
    ]);
  });

  test('an exact multiple of the cap ends with one empty page', () async {
    final client = clientWith(2000);
    expect(await fetchAllRows(catalogue(client)), hasLength(2000));
    expect(catalogueRequests(), hasLength(3));
  });

  test('a result under the cap is one request', () async {
    final client = clientWith(42);
    expect(await fetchAllRows(catalogue(client)), hasLength(42));
    expect(catalogueRequests(), hasLength(1));
  });

  test('every page keeps the unique id order', () async {
    final client = clientWith(1500);
    await fetchAllRows(catalogue(client));
    for (final u in catalogueRequests()) {
      expect(u.queryParameters['order'], 'id.asc.nullslast');
    }
  });

  test('getCountries sees a country that only appears after row 1000',
      () async {
    final client = clientWith(1500, countryOf: (i) => i < 1200 ? 'FR' : 'DE');
    final countries = await RestaurantRepository(
      client,
    ).getCountries(starsOnly: true);
    final pages = catalogueRequests();
    expect(pages, hasLength(2));
    for (final u in pages) {
      expect(u.queryParameters['michelin_stars'], 'not.is.null');
    }
    // DE's rows are 1200-1499: a single capped request would have missed it.
    expect(countries.map((c) => c.code).toSet(), {'DE', 'FR'});
  });
}
