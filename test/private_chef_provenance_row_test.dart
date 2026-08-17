// Covers PrivateChefProvenanceRow — the hard Michelin-attribution rule
// (StarRow only beside a canonical Restaurant's own name, never inferred
// for the chef), canonical vs text-only rendering/tappability, and the
// gold audit (StarRow is the only permitted gold producer in this
// feature).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_provenance_row.dart';
import 'package:michelin_passport/models/private_chef_restaurant_history.dart';
import 'package:michelin_passport/models/restaurant.dart';

const _starredRestaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Parkheuvel',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Some address',
);

const _unstarredRestaurant = Restaurant(
  id: 'r2',
  restaurantCode: 'r2',
  name: 'A Restaurant',
  michelinStars: null,
  inclusionReason: 'michelin_star',
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Some address',
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('PrivateChefProvenanceRow — canonical', () {
    final history = PrivateChefRestaurantHistory.fromRow({
      'id': 'h1',
      'private_chef_id': 'c1',
      'restaurant_id': 'r1',
      'restaurant_name_text': null,
      'role': 'Sous Chef',
      'period_text': '2019–2022',
      'display_order': 0,
    }, restaurant: _starredRestaurant);

    testWidgets('renders the restaurant name and role/period', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history, onTap: () {})),
      );
      // The restaurant name renders inside a Text.rich span alongside its
      // StarRow WidgetSpans, so find.text's exact-match doesn't apply here
      // (toPlainText() includes the WidgetSpans' placeholder characters)
      // — find.textContaining is the correct finder for this case.
      expect(find.textContaining('Parkheuvel'), findsOneWidget);
      expect(find.text('Sous Chef · 2019–2022'), findsOneWidget);
    });

    testWidgets('renders StarRow beside the restaurant name, matching the '
        'restaurant\'s own current recognition', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history, onTap: () {})),
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });

    testWidgets('never renders "chef has N Michelin stars" phrasing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history, onTap: () {})),
      );
      expect(find.textContaining('chef has'), findsNothing);
      expect(find.textContaining('Michelin-starred chef'), findsNothing);
    });

    testWidgets('shows city + flag from the canonical restaurant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history, onTap: () {})),
      );
      expect(find.text('Rotterdam'), findsOneWidget);
      expect(find.text('🇳🇱'), findsOneWidget);
    });

    testWidgets('tapping fires onTap (navigates to canonical Restaurant '
        'Detail)', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrivateChefProvenanceRow(
            history: history,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(PrivateChefProvenanceRow));
      expect(tapped, isTrue);
    });

    testWidgets('a canonical restaurant with no current star renders no '
        'StarRow at all', (tester) async {
      final unstarred = PrivateChefRestaurantHistory.fromRow({
        'id': 'h2',
        'private_chef_id': 'c1',
        'restaurant_id': 'r2',
        'restaurant_name_text': null,
        'role': null,
        'period_text': null,
        'display_order': 0,
      }, restaurant: _unstarredRestaurant);
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: unstarred, onTap: () {})),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('PrivateChefProvenanceRow — text-only fallback', () {
    final history = PrivateChefRestaurantHistory.fromRow({
      'id': 'h3',
      'private_chef_id': 'c1',
      'restaurant_id': null,
      'restaurant_name_text': 'A small regional restaurant',
      'role': 'Head Chef',
      'period_text': 'Several seasons',
      'display_order': 0,
    });

    testWidgets('renders the text-only name and role/period', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history)),
      );
      expect(find.text('A small regional restaurant'), findsOneWidget);
      expect(find.text('Head Chef · Several seasons'), findsOneWidget);
    });

    testWidgets('never shows stars', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history)),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('never shows a fabricated city/flag/location', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history)),
      );
      expect(find.textContaining('🇳🇱'), findsNothing);
    });

    testWidgets('is not tappable — no InkWell/Material wrapping, no arrow '
        'affordance', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefProvenanceRow(history: history)),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });
  });

  testWidgets('gold audit: StarRow is the only gold producer — no other '
      'gold text in either variant', (tester) async {
    final canonical = PrivateChefRestaurantHistory.fromRow({
      'id': 'h1',
      'private_chef_id': 'c1',
      'restaurant_id': 'r1',
      'restaurant_name_text': null,
      'role': 'Sous Chef',
      'period_text': '2019–2022',
      'display_order': 0,
    }, restaurant: _starredRestaurant);
    await tester.pumpWidget(
      _wrap(PrivateChefProvenanceRow(history: canonical, onTap: () {})),
    );
    // Only plain Text widgets are checked here — Icon internally renders
    // via RichText with its own color, so checking RichText too would
    // incorrectly flag StarRow's own legitimate gold star glyphs.
    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final text in texts) {
      expect(text.style?.color, isNot(AppColors.gold));
    }
  });
}
