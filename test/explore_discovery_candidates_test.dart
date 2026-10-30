// Explore's Discovery used to download the whole catalogue (3,480
// restaurants + 1,830 hotels, about 1 MB gzipped per mount, measured
// 2026-10-30) to show eight of each. It now fetches only the candidates
// each section can show. Asserted here against a fake PostgREST that sorts,
// filters and caps the way the real one does: the selectors must pick
// exactly what they picked from the full catalogue, in a handful of rows.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/data/repositories/fetch_all_rows.dart';
import 'package:michelin_passport/data/repositories/hotel_repository.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';
import 'package:michelin_passport/features/explore/discovery_selectors.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<Uri> requests;
  late int rowsServed;

  // One PostgREST "order" term (`col.asc.nullslast`) as a comparator.
  int Function(Map<String, dynamic>, Map<String, dynamic>) termComparator(
    String term,
  ) {
    final parts = term.split('.');
    final col = parts[0];
    final desc = parts.contains('desc');
    final nullsFirst = parts.contains('nullsfirst');
    return (a, b) {
      final x = a[col], y = b[col];
      if (x == null && y == null) return 0;
      if (x == null) return nullsFirst ? -1 : 1;
      if (y == null) return nullsFirst ? 1 : -1;
      final c = (x as Comparable).compareTo(y);
      return desc ? -c : c;
    };
  }

  SupabaseClient clientWith(Map<String, List<Map<String, dynamic>>> views) {
    requests = [];
    rowsServed = 0;
    return SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final view = request.url.pathSegments.last;
        var rows = [...?views[view]];
        final q = request.url.queryParameters;
        for (final MapEntry(:key, :value) in q.entries) {
          if (const {'select', 'order', 'limit', 'offset'}.contains(key)) {
            continue;
          }
          if (value == 'is.null') {
            rows = rows.where((r) => r[key] == null).toList();
          } else if (value == 'not.is.null') {
            rows = rows.where((r) => r[key] != null).toList();
          } else if (value.startsWith('eq.')) {
            final want = value.substring(3);
            rows = rows.where((r) => '${r[key]}' == want).toList();
          } else {
            fail('unexpected filter $key=$value');
          }
        }
        final terms = (q['order'] ?? '').split(',').where((t) => t.isNotEmpty);
        final comparators = terms.map(termComparator).toList();
        rows.sort((a, b) {
          for (final c in comparators) {
            final r = c(a, b);
            if (r != 0) return r;
          }
          return 0;
        });
        final offset = int.parse(q['offset'] ?? '0');
        final limit = int.parse(q['limit'] ?? '$catalogueRowCap');
        final page = rows
            .skip(offset)
            .take(limit < catalogueRowCap ? limit : catalogueRowCap)
            .toList();
        rowsServed += page.length;
        return http.Response(jsonEncode(page), 200, request: request);
      }),
    );
  }

  Map<String, dynamic> restaurant(
    int i, {
    int? stars,
    int? rank,
    String? name,
    String? reportId,
    String? createdAt,
  }) => {
    'id': 'r${i.toString().padLeft(5, '0')}',
    'name': name ?? 'Restaurant $i',
    'michelin_stars': stars,
    'worlds_50_best_rank': rank,
    'missing_listing_report_id': reportId,
    'created_at': createdAt ?? '2026-01-01T00:00:00Z',
  };

  List<String> ids(Iterable<dynamic> venues) => [
    for (final v in venues) (v as dynamic).id as String,
  ];

  group('Worth the Journey candidates', () {
    test('match the full-catalogue pick when ranked rows decide it', () async {
      // Production's shape: plenty of ranked three-stars, so the top eight
      // are decided on stars and rank alone.
      final rows = [
        for (var i = 0; i < 30; i++) restaurant(i, stars: 3, rank: 50 - i),
        for (var i = 30; i < 160; i++) restaurant(i, stars: 3),
        for (var i = 160; i < 3000; i++) restaurant(i, stars: i % 3),
      ];
      final repo = RestaurantRepository(clientWith({'restaurants_full': rows}));
      final candidates = await repo.getDiscoveryCandidates();
      final all = rows.map(Restaurant.fromJson).toList();

      expect(
        ids(selectDiscoveryRestaurants(candidates)),
        ids(selectDiscoveryRestaurants(all)),
      );
      expect(requests, hasLength(1));
      expect(rowsServed, 9);
    });

    test(
      'fetch the whole tie group when it straddles the eighth place, '
      'so the client-side name order decides, not the server collation',
      () async {
        // Two ranked three-stars, then 200 unranked three-stars whose names
        // sort differently by code unit (Dart) than by id (server).
        final rows = [
          restaurant(0, stars: 3, rank: 1),
          restaurant(1, stars: 3, rank: 2),
          for (var i = 2; i < 202; i++)
            restaurant(i, stars: 3, name: i.isEven ? 'Ébène $i' : 'auberge $i'),
          restaurant(202, stars: 3, name: 'Alpha'),
          for (var i = 203; i < 1500; i++) restaurant(i, stars: 2, rank: 3),
        ];
        final repo = RestaurantRepository(
          clientWith({'restaurants_full': rows}),
        );
        final candidates = await repo.getDiscoveryCandidates();
        final all = rows.map(Restaurant.fromJson).toList();

        final picked = ids(selectDiscoveryRestaurants(candidates));
        expect(picked, ids(selectDiscoveryRestaurants(all)));
        expect(picked, contains('r00202')); // 'Alpha', last by id
        expect(requests, hasLength(2));
        expect(requests.last.queryParameters['michelin_stars'], 'eq.3');
        expect(requests.last.queryParameters['worlds_50_best_rank'], 'is.null');
      },
    );

    test('handle a catalogue with fewer starred rows than the limit', () async {
      final rows = [
        restaurant(0, stars: 1),
        restaurant(1, stars: 0),
        for (var i = 2; i < 20; i++) restaurant(i),
      ];
      final repo = RestaurantRepository(clientWith({'restaurants_full': rows}));
      final candidates = await repo.getDiscoveryCandidates();
      final all = rows.map(Restaurant.fromJson).toList();

      expect(
        ids(selectDiscoveryRestaurants(candidates)),
        ids(selectDiscoveryRestaurants(all)),
      );
    });

    test(
      'return everything when the catalogue is smaller than the limit',
      () async {
        final rows = [for (var i = 0; i < 5; i++) restaurant(i, stars: 2)];
        final repo = RestaurantRepository(
          clientWith({'restaurants_full': rows}),
        );
        expect(await repo.getDiscoveryCandidates(), hasLength(5));
        expect(requests, hasLength(1));
      },
    );
  });

  test(
    'Stay a Little Longer candidates match the full-catalogue pick',
    () async {
      final rows = [
        for (var i = 0; i < 1830; i++)
          {
            'id': 'h${i.toString().padLeft(5, '0')}',
            'name': 'Hotel ${1830 - i}',
            'michelin_keys': i < 116 ? 3 : (i < 900 ? (i % 2) + 1 : null),
            'worlds_50_best_rank': i % 40 == 0 ? i ~/ 40 + 1 : null,
          },
      ];
      final repo = HotelRepository(clientWith({'hotels_full': rows}));
      final candidates = await repo.getDiscoveryCandidates();
      final all = rows.map(Hotel.fromJson).toList();

      // Only three ranked three-Key hotels, so the unranked three-Key tie
      // group (113 rows) comes back too — still a fraction of 1,830.
      expect(rowsServed, 9 + 113);
      expect(
        ids(selectDiscoveryHotels(candidates)),
        ids(selectDiscoveryHotels(all)),
      );
    },
  );

  test('Fresh Finds candidates are the newest reported rows only', () async {
    final rows = [
      for (var i = 0; i < 2000; i++) restaurant(i, stars: 1),
      for (var i = 2000; i < 2015; i++)
        restaurant(
          i,
          reportId: 'm$i',
          createdAt:
              '2026-10-${(i - 1999).toString().padLeft(2, '0')}T00:00:00Z',
        ),
    ];
    final repo = RestaurantRepository(clientWith({'restaurants_full': rows}));
    final candidates = await repo.getFreshFindCandidates();
    final all = rows.map(Restaurant.fromJson).toList();

    final fromCandidates = selectFreshFinds(
      restaurants: candidates,
      hotels: const [],
      events: const [],
    );
    final fromAll = selectFreshFinds(
      restaurants: all,
      hotels: const [],
      events: const [],
    );
    expect(fromCandidates.map((f) => f.name), fromAll.map((f) => f.name));
    expect(rowsServed, 10);
  });
}
