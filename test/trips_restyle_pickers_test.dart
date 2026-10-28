// Trips restyle (2026-10-28): destination-scoped venue pickers and the
// shared Trips chrome. The pickers must hand the trip's country CODE to the
// catalogue search (never a name), and nothing in the shared chrome may be
// gold — CLAUDE.md reserves gold for MICHELIN stars and Keys.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/data/repositories/hotel_repository.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';
import 'package:michelin_passport/features/trips/widgets/hotel_picker_sheet.dart';
import 'package:michelin_passport/features/trips/widgets/planned_venue_row.dart';
import 'package:michelin_passport/features/trips/widgets/restaurant_picker_sheet.dart';
import 'package:michelin_passport/features/trips/widgets/trip_chrome.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_venue.dart';
import 'package:michelin_passport/models/resolved_planned_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Restaurant _restaurant(String id, String name, {int? stars}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: stars,
  inclusionReason: 'michelin_star',
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  isInHotel: false,
  hotelName: null,
  worlds50BestRank: null,
);

Hotel _hotel(String id, String name) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: 2,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: null,
);

class _RecordingRestaurantRepository extends RestaurantRepository {
  _RecordingRestaurantRepository() : super(_dummyClient());

  final List<List<String>> countryCodes = [];
  final List<List<String>> cityIds = [];

  @override
  Future<List<Restaurant>> searchInPlaces(
    String query, {
    List<String> countryCodes = const [],
    List<String> cityIds = const [],
  }) async {
    this.countryCodes.add(countryCodes);
    this.cityIds.add(cityIds);
    return [
      _restaurant('r3', 'Auberge du Test'),
      _restaurant('r2', 'Le Nouveau', stars: 2),
      _restaurant('r1', 'Already On Trip', stars: 1),
    ];
  }
}

class _RecordingHotelRepository extends HotelRepository {
  _RecordingHotelRepository() : super(_dummyClient());

  final List<List<String>> countryCodes = [];

  @override
  Future<List<Hotel>> searchInPlaces(
    String query, {
    List<String> countryCodes = const [],
    List<String> cityIds = const [],
  }) async {
    this.countryCodes.add(countryCodes);
    return [_hotel('h1', 'Hôtel Test')];
  }
}

/// A button that opens [open] and stores its result, so a test can drive
/// the real modal sheet and read back what it returned.
class _Opener<T> extends StatefulWidget {
  final Future<T?> Function(BuildContext context) open;
  final ValueChanged<T?> onResult;
  const _Opener({required this.open, required this.onResult});

  @override
  State<_Opener<T>> createState() => _OpenerState<T>();
}

class _OpenerState<T> extends State<_Opener<T>> {
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async => widget.onResult(await widget.open(context)),
      child: const Text('open'),
    ),
  );
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('Destination-scoped pickers', () {
    testWidgets('restaurant picker searches the trip\'s destinations by '
        'city id and country code, and hides restaurants already on the '
        'trip', (tester) async {
      final repo = _RecordingRestaurantRepository();
      Restaurant? picked;
      await tester.pumpWidget(
        _app(
          _Opener<Restaurant>(
            open: (context) => showRestaurantPickerSheet(
              context,
              repo: repo,
              countryCodes: const ['IT'],
              cityIds: const ['city-paris'],
              destinationLabel: 'Paris, 🇫🇷 France · 🇮🇹 Italy',
              excludeIds: {'r1'},
            ),
            onResult: (r) => picked = r,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(repo.countryCodes, [
        ['IT'],
      ]);
      expect(repo.cityIds, [
        ['city-paris'],
      ]);
      expect(
        find.text('Restaurants in Paris, 🇫🇷 France · 🇮🇹 Italy'),
        findsOneWidget,
      );
      expect(find.text('Already On Trip'), findsNothing);
      expect(find.text('Le Nouveau'), findsOneWidget);
      // Shown in the order the (A→Z) search returned.
      expect(
        tester.getTopLeft(find.text('Auberge du Test')).dy,
        lessThan(tester.getTopLeft(find.text('Le Nouveau')).dy),
      );

      // Typing keeps the same country scope.
      await tester.enterText(find.byType(TextField), 'nou');
      await tester.pumpAndSettle();
      expect(repo.countryCodes, [
        ['IT'],
        ['IT'],
      ]);

      await tester.tap(find.text('Le Nouveau'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'r2');
    });

    testWidgets('hotel picker searches by the destination country code', (
      tester,
    ) async {
      final repo = _RecordingHotelRepository();
      Hotel? picked;
      await tester.pumpWidget(
        _app(
          _Opener<Hotel>(
            open: (context) => showHotelPickerSheet(
              context,
              repo: repo,
              countryCodes: const ['FR'],
              destinationLabel: '🇫🇷 France',
            ),
            onResult: (h) => picked = h,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(repo.countryCodes, [
        ['FR'],
      ]);
      expect(find.text('Hotels in 🇫🇷 France'), findsOneWidget);
      // The Key row is the only gold on the sheet.
      expect(find.byIcon(Icons.vpn_key_rounded), findsNWidgets(2));

      await tester.tap(find.text('Hôtel Test'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'h1');
    });
  });

  group('Trips chrome', () {
    testWidgets('TripTextAction is ivory, never gold, and inert when '
        'disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              TripTextAction(label: 'Add stay', onTap: () => taps++),
              TripTextAction(
                label: 'Add hotel',
                onTap: () => taps++,
                enabled: false,
              ),
            ],
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
      await tester.tap(find.text('Add stay'));
      await tester.tap(find.text('Add hotel'));
      expect(taps, 1);
    });

    testWidgets('TripSectionHeader renders title, subtitle and trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TripSectionHeader(
            title: 'STAY',
            subtitle: 'Where you’ll rest.',
            trailing: TripTextAction(label: 'Add stay', onTap: () {}),
          ),
        ),
      );
      expect(find.text('STAY'), findsOneWidget);
      expect(find.text('Where you’ll rest.'), findsOneWidget);
      expect(find.text('Add stay'), findsOneWidget);
    });

    testWidgets('PlannedVenueRow shows a trailing control when given one', (
      tester,
    ) async {
      final item = ResolvedPlannedVenue(
        plan: PlannedVenue(
          id: 'p1',
          userId: 'u1',
          entityType: 'restaurant',
          entityId: 'r2',
          tripId: 't1',
          startDate: DateTime(2026, 10, 17),
          status: PlannedVenueStatus.planned,
          createdAt: DateTime(2026, 9, 1),
        ),
        venue: RestaurantVenue(_restaurant('r2', 'Le Nouveau', stars: 2)),
      );
      await tester.pumpWidget(
        _app(
          PlannedVenueRow(
            item: item,
            onTap: () {},
            trailing: const Icon(Icons.close_rounded),
          ),
        ),
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });
  });
}
