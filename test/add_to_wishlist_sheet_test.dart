import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/wishlist/widgets/add_to_wishlist_sheet.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

PassportVenue _restaurant(String id, String name) => RestaurantVenue(
  Restaurant.fromJson({'id': id, 'name': name, 'city_name': 'Zwolle'}),
);

PassportVenue _hotel(String id, String name) => HotelVenue(
  Hotel.fromJson({'id': id, 'name': name, 'city_name': 'Amsterdam'}),
);

Event _event(String id, String name) => Event.fromJson({
  'id': id,
  'name': name,
  'country_code': 'NL',
  'city': 'Zwolle',
  'start_date': '2026-11-20',
  'end_date': '2026-11-20',
  'timezone': 'Europe/Amsterdam',
  'event_type': 'dinner',
  'created_at': '2026-10-01T10:00:00Z',
});

void main() {
  late List<String> added;
  late List<String> removed;
  late List<String> restaurantQueries;
  late List<String> hotelQueries;
  late List<String> eventQueries;
  bool? closedWith;

  setUp(() {
    added = [];
    removed = [];
    restaurantQueries = [];
    hotelQueries = [];
    eventQueries = [];
    closedWith = null;
  });

  String idOf(PassportVenue v) => switch (v) {
    RestaurantVenue(:final restaurant) => restaurant.id,
    HotelVenue(:final hotel) => hotel.id,
  };

  Future<void> pumpOpener(
    WidgetTester tester, {
    Set<String> savedIds = const {},
    WishlistAddType startWith = WishlistAddType.restaurant,
    bool failWrites = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  closedWith = await showAddToWishlistSheet(
                    context,
                    userId: 'u1',
                    savedIds: savedIds,
                    startWith: startWith,
                    searchRestaurants: (q) async {
                      restaurantQueries.add(q);
                      return [_restaurant('r1', 'De Librije')];
                    },
                    searchHotels: (q) async {
                      hotelQueries.add(q);
                      return [_hotel('h1', 'Pulitzer')];
                    },
                    searchEvents: (q) async {
                      eventQueries.add(q);
                      return [_event('e1', 'Four Hands at De Librije')];
                    },
                    addEvent: (e) async {
                      if (failWrites) throw Exception('offline');
                      added.add(e.id);
                    },
                    removeEvent: (e) async {
                      if (failWrites) throw Exception('offline');
                      removed.add(e.id);
                    },
                    add: (v) async {
                      if (failWrites) throw Exception('offline');
                      added.add(idOf(v));
                    },
                    remove: (v) async {
                      if (failWrites) throw Exception('offline');
                      removed.add(idOf(v));
                    },
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('a search result is saved with the heart, removed with a '
      'second tap, and Done reports a change', (tester) async {
    await pumpOpener(tester);
    expect(find.text('Where would you like to go?'), findsOneWidget);

    await search(tester, 'Libr');
    expect(restaurantQueries, ['Libr']);
    expect(find.text('De Librije'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Save to wishlist'));
    await tester.pumpAndSettle();
    expect(added, ['r1']);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(removed, ['r1']);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(closedWith, isTrue);
  });

  testWidgets('a venue already on the wishlist starts with a filled heart', (
    tester,
  ) async {
    await pumpOpener(tester, savedIds: {'r1'});
    await search(tester, 'Libr');
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('opened from the Hotels tab it searches hotels, and the chip '
      'switches type', (tester) async {
    await pumpOpener(tester, startWith: WishlistAddType.hotel);
    await search(tester, 'Puli');
    expect(hotelQueries, ['Puli']);
    expect(find.text('Pulitzer'), findsOneWidget);

    await tester.tap(find.text('Restaurant'));
    await tester.pumpAndSettle();
    expect(restaurantQueries, ['Puli']);
    expect(find.text('De Librije'), findsOneWidget);
  });

  testWidgets('a failed write flips the heart back and says so, and Done '
      'reports no change', (tester) async {
    await pumpOpener(tester, failWrites: true);
    await search(tester, 'Libr');
    await tester.tap(find.byTooltip('Save to wishlist'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(
      find.text('Could not update your wishlist. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(closedWith, isFalse);
  });

  testWidgets('the Event chip searches upcoming events, and the heart saves '
      'one', (tester) async {
    await pumpOpener(tester);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    await search(tester, 'Four');
    expect(eventQueries, ['Four']);
    expect(find.text('Four Hands at De Librije'), findsOneWidget);

    await tester.tap(find.byTooltip('Save to wishlist'));
    await tester.pumpAndSettle();
    expect(added, ['e1']);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('opened from the Events tab it starts on events', (tester) async {
    await pumpOpener(tester, startWith: WishlistAddType.event);
    expect(find.text('Search for an upcoming event to save.'), findsOneWidget);
    await search(tester, 'Four');
    expect(eventQueries, ['Four']);
    expect(restaurantQueries, isEmpty);
  });
}
