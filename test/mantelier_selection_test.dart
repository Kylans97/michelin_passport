// The editorial Selection in the app: Explore's "Mantelier's latest" and
// the Guides Selection catalogue. The Selection is editorial judgement,
// never an award — its label is forest green, never gold, and an unstarred
// Selection restaurant never shows an empty star row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/data/repositories/editorial_selection_repository.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_cards.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_sections.dart';
import 'package:michelin_passport/features/guides/selection_restaurant_guide_screen.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant(
  String id,
  String name, {
  int? stars,
  String city = 'Amsterdam',
  String countryCode = 'NL',
  String country = 'Netherlands',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: stars,
  inclusionReason: 'editorial_selection',
  cityName: city,
  countryCode: countryCode,
  countryName: country,
  flagEmoji: '',
  address: 'a',
);

SelectionEntry _entry(Restaurant r) =>
    (restaurant: r, selectedOn: DateTime(2026, 10, 28));

void main() {
  group("MantelierLatestSection", () {
    testWidgets('renders nothing without Selection restaurants', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MantelierLatestSection(
              restaurants: const [],
              onTapRestaurant: (_) {},
            ),
          ),
        ),
      );
      expect(find.text("MANTELIER'S LATEST"), findsNothing);
    });

    testWidgets('shows the restaurants with a forest-green Selection label', (
      tester,
    ) async {
      Restaurant? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MantelierLatestSection(
              restaurants: [
                _restaurant('r1', 'Tacite'),
                _restaurant('r2', 'Petit Péché'),
              ],
              onTapRestaurant: (r) => tapped = r,
            ),
          ),
        ),
      );
      expect(find.text("MANTELIER'S LATEST"), findsOneWidget);
      expect(find.text('Tacite'), findsOneWidget);
      final labels = tester.widgetList<Text>(
        find.text(mantelierSelectionLabel),
      );
      expect(labels, isNotEmpty);
      for (final label in labels) {
        expect(label.style?.color, AppColors.forestGreen);
        expect(label.style?.color, isNot(AppColors.gold));
      }
      await tester.tap(find.text('Tacite'));
      expect(tapped?.id, 'r1');
    });

    testWidgets('a starred Selection restaurant shows its stars, not the '
        'label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreDiscoveryRestaurantCard(
              restaurant: _restaurant('r3', 'Starred', stars: 1),
              inSelection: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text(mantelierSelectionLabel), findsNothing);
    });
  });

  group('SelectionRestaurantGuideScreen', () {
    final entries = [
      _entry(_restaurant('r1', 'Tacite')),
      _entry(_restaurant('r2', 'Petit Péché')),
      _entry(
        _restaurant(
          'r3',
          'Le Test',
          stars: 2,
          city: 'Paris',
          countryCode: 'FR',
          country: 'France',
        ),
      ),
    ];

    testWidgets('lists every entry; search narrows on the device', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectionRestaurantGuideScreen(load: () async => entries),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 places'), findsOneWidget);
      expect(find.text('Tacite'), findsOneWidget);
      // Unstarred rows carry the Selection label, the starred one its stars.
      expect(find.text(mantelierSelectionLabel), findsNWidgets(2));
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'paris');
      await tester.pumpAndSettle();
      expect(find.text('1 place'), findsOneWidget);
      expect(find.textContaining('Le Test', findRichText: true), findsOneWidget);
      expect(find.text('Tacite'), findsNothing);
    });

    testWidgets('an empty Selection shows the empty state, not an error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectionRestaurantGuideScreen(load: () async => const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 places'), findsOneWidget);
    });
  });
}
