// EVENT WISHLIST V1: covers EventWishlistCard — the ivory CsPlaceCard-family
// card for a saved Event. Mirrors wishlist_venue_cards_test.dart's own
// fixture pattern and documented limitation: tapping through to
// EventDetailScreen isn't exercised here since it constructs a
// Supabase-backed repository eagerly with no session in this sandbox —
// presence of the tap affordance is verified structurally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/features/wishlist/widgets/event_wishlist_card.dart';
import 'package:michelin_passport/models/event.dart';

Event _event({
  String name = "'t Preuvenemint",
  String? city = 'Maastricht',
  String countryCode = 'NL',
  String? imageUrl,
}) => Event(
  id: 'e1',
  name: name,
  startDate: DateTime.utc(2026, 8, 27),
  endDate: DateTime.utc(2026, 8, 30),
  timezone: 'UTC',
  countryCode: countryCode,
  city: city,
  imageUrl: imageUrl,
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('EventWishlistCard', () {
    testWidgets('renders name, city/country, date range and the canonical '
        'image fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(EventWishlistCard(event: _event(), onRemove: () {})),
      );
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.text('Maastricht, NL'), findsOneWidget);
      expect(find.text('27–30 Aug 2026'), findsOneWidget);
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing city omits it, keeps the country code', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventWishlistCard(event: _event(city: null), onRemove: () {}),
        ),
      );
      expect(find.text('NL'), findsOneWidget);
    });

    testWidgets('the bookmark is filled (already-saved state) — tapping it '
        'fires onRemove, not card navigation', (tester) async {
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          EventWishlistCard(event: _event(), onRemove: () => removed = true),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      expect(removed, isTrue);
    });

    testWidgets('never renders a heart icon — the card uses the same '
        'bookmark-remove convention as the restaurant/hotel wishlist '
        'cards, not the Detail-screen heart', (tester) async {
      await tester.pumpWidget(
        _wrap(EventWishlistCard(event: _event(), onRemove: () {})),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('renders as a tappable card (navigation entry point)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventWishlistCard(event: _event(), onRemove: () {})),
      );
      expect(find.byType(InkWell), findsWidgets);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px — long name, long '
          'city/country', (tester) async {
        await tester.pumpWidget(
          _wrap(
            EventWishlistCard(
              event: _event(
                name: 'An Exceptionally Long Gastronomy Festival Name',
                city: 'A Fairly Long City Name',
              ),
              onRemove: () {},
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 1.6x text scale, 320px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: EventWishlistCard(event: _event(), onRemove: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
