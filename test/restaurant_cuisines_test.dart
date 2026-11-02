// Restaurant cuisines (20261101150000, applied 2026-11-02): the model reads
// restaurants_full's cuisine columns, free search also matches cuisine
// names, Explore's cuisine filter overlaps on family slugs and offers only
// the families that exist, and the detail page shows the cuisine quietly.
//
// Repository requests go to a MockClient, so the PostgREST query each call
// builds is asserted directly. The detail-screen test pumps the real
// RestaurantDetailScreen in preview mode the way venue_preview_test.dart
// does (it needs Supabase.initialize with the public anon key from .env;
// its venue-level loads fail in the test sandbox and are tolerated).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/core/widgets/cuisine_filter_control.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';
import 'package:michelin_passport/features/restaurants/restaurant_detail_screen.dart';
import 'package:michelin_passport/models/cuisine_family.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _families = [
  CuisineFamily(slug: 'modern-creative', name: 'Modern & creative'),
  CuisineFamily(slug: 'japanese', name: 'Japanese'),
  CuisineFamily(slug: 'seafood', name: 'Seafood'),
];

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Sushi Saito',
  michelinStars: 3,
  inclusionReason: 'michelin_star',
  cityName: 'Tokyo',
  countryCode: 'JP',
  countryName: 'Japan',
  flagEmoji: '🇯🇵',
  address: 'Some address',
  cuisineNames: 'Japanese, Sushi',
  cuisineFamilySlugs: ['japanese'],
);

void main() {
  group('Restaurant cuisine fields', () {
    test('parses cuisine_names and cuisine_family_slugs', () {
      final r = Restaurant.fromJson({
        'id': 'r1',
        'cuisine_names': 'Modern Cuisine, Creative',
        'cuisine_family_slugs': ['modern-creative'],
      });
      expect(r.cuisineNames, 'Modern Cuisine, Creative');
      expect(r.cuisineFamilySlugs, ['modern-creative']);
      expect(r.cuisineLabel, 'Modern Cuisine · Creative');
    });

    test('no cuisine known: null label, empty families', () {
      final r = Restaurant.fromJson({'id': 'r1'});
      expect(r.cuisineNames, isNull);
      expect(r.cuisineFamilySlugs, isEmpty);
      expect(r.cuisineLabel, isNull);
      expect(
        Restaurant.fromJson({'id': 'r1', 'cuisine_names': ' '}).cuisineLabel,
        isNull,
      );
    });

    test('restaurantFullColumns selects the cuisine columns', () {
      expect(restaurantFullColumns, contains('cuisine_names'));
      expect(restaurantFullColumns, contains('cuisine_family_slugs'));
    });
  });

  group('RestaurantRepository', () {
    late List<Uri> requests;

    RestaurantRepository repoWith(
      List<Map<String, dynamic>> Function(Uri) respond,
    ) {
      requests = [];
      return RestaurantRepository(
        SupabaseClient(
          'https://test.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response(
              jsonEncode(respond(request.url)),
              200,
              request: request,
            );
          }),
        ),
      );
    }

    test('free search also matches cuisine_search', () async {
      final repo = repoWith((_) => const []);
      await repo.search('sushi');
      final or = requests.single.queryParametersAll['or']!;
      expect(or, hasLength(1));
      expect(or.single, contains('cuisine_search.ilike.%sushi%'));
      expect(or.single, contains('name.ilike.%sushi%'));
      expect(
        requests.single.queryParameters,
        isNot(contains('cuisine_family_slugs')),
      );
    });

    test('each word may match a different field, cuisine included', () async {
      final repo = repoWith((_) => const []);
      await repo.search('sushi tokyo');
      final or = requests.single.queryParametersAll['or']!;
      expect(or, hasLength(2));
      expect(or[0], contains('cuisine_search.ilike.%sushi%'));
      expect(or[1], contains('city_name.ilike.%tokyo%'));
    });

    test('a cuisine filter overlaps on the family slugs', () async {
      final repo = repoWith((_) => const []);
      await repo.search('', cuisineFamilies: {'seafood', 'japanese'});
      expect(
        requests.single.queryParameters['cuisine_family_slugs'],
        'ov.{"japanese","seafood"}',
      );
    });

    test('getCuisineFamilies offers only families some restaurant has, '
        'in display order', () async {
      final repo = repoWith((url) {
        if (url.pathSegments.last == 'cuisine_families') {
          return [
            for (final f in _families) {'slug': f.slug, 'name': f.name},
          ];
        }
        return [
          {
            'id': 'a',
            'cuisine_family_slugs': ['seafood'],
          },
          {
            'id': 'b',
            'cuisine_family_slugs': ['seafood', 'modern-creative'],
          },
        ];
      });
      final families = await repo.getCuisineFamilies();
      expect(families.map((f) => f.slug), ['modern-creative', 'seafood']);
      final familiesRequest = requests.firstWhere(
        (u) => u.pathSegments.last == 'cuisine_families',
      );
      expect(
        familiesRequest.queryParameters['order'],
        startsWith('display_order.asc'),
      );
    });
  });

  group('CuisineFilterControl', () {
    test('label summarises the selection in family order', () {
      expect(CuisineFilterControl.labelFor({}, _families), 'All cuisines');
      expect(CuisineFilterControl.labelFor({'seafood'}, _families), 'Seafood');
      expect(
        CuisineFilterControl.labelFor({'seafood', 'japanese'}, _families),
        'Japanese +1',
      );
    });

    Future<List<Set<String>>> pumpControl(
      WidgetTester tester, {
      Set<String> selected = const {},
    }) async {
      final changes = <Set<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CuisineFilterControl(
                selected: selected,
                families: _families,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CuisineFilterControl));
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('ticking families and applying passes them on', (tester) async {
      final changes = await pumpControl(tester);
      await tester.tap(find.text('Japanese'));
      await tester.tap(find.text('Seafood'));
      await tester.pump();
      await tester.tap(find.text('Show restaurants'));
      await tester.pumpAndSettle();
      expect(changes, [
        {'japanese', 'seafood'},
      ]);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final changes = await pumpControl(tester, selected: {'japanese'});
      await tester.tap(find.text('Seafood'));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('Clear unticks everything', (tester) async {
      final changes = await pumpControl(
        tester,
        selected: {'japanese', 'seafood'},
      );
      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.tap(find.text('Show restaurants'));
      await tester.pumpAndSettle();
      expect(changes, [<String>{}]);
    });
  });

  group('RestaurantDetailScreen', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await dotenv_pkg.dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv_pkg.dotenv.env['SUPABASE_URL']!,
        // ignore: deprecated_member_use
        anonKey: dotenv_pkg.dotenv.env['SUPABASE_ANON_KEY']!,
      );
    });

    testWidgets('shows the cuisine under the city line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(
            restaurant: _restaurant,
            isPreview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Japanese · Sushi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows nothing when no cuisine is known', (tester) async {
      const plain = Restaurant(
        id: 'r2',
        restaurantCode: 'r2',
        name: 'Somewhere',
        michelinStars: 1,
        inclusionReason: 'michelin_star',
        cityName: 'Tokyo',
        countryCode: 'JP',
        countryName: 'Japan',
        flagEmoji: '🇯🇵',
        address: 'Some address',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(restaurant: plain, isPreview: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(' · '), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
