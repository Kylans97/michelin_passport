// Covers formatGuestRange/formatPricingFrom (pure functions) and
// PrivateChefExperienceSection's conditional rendering — the section must
// render only the lines actually derivable from PrivateChef's fields, and
// omit itself entirely when there is nothing to show.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_experience_section.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _bareChef = PrivateChef(
  id: 'c1',
  slug: 'chef',
  displayName: 'Chef',
  travelAvailable: false,
  priceOnRequest: false,
);

void main() {
  group('formatGuestRange', () {
    test('neither bound set -> null (never "null–null guests")', () {
      expect(formatGuestRange(_bareChef), isNull);
    });

    test('both bounds -> "min–max guests"', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        minimumGuests: 6,
        maximumGuests: 14,
      );
      expect(formatGuestRange(chef), '6–14 guests');
    });

    test('minimum only -> "From min guests"', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        minimumGuests: 6,
      );
      expect(formatGuestRange(chef), 'From 6 guests');
    });

    test('maximum only -> "Up to max guests"', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        maximumGuests: 14,
      );
      expect(formatGuestRange(chef), 'Up to 14 guests');
    });
  });

  group('formatPricingFrom', () {
    test('price on request -> null regardless of pricingFrom', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        pricingFrom: 450,
      );
      expect(formatPricingFrom(chef), isNull);
    });

    test('whole-number amount with currency and per-person unit', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        priceOnRequest: false,
        pricingFrom: 450,
        pricingCurrency: 'EUR',
        pricingUnit: 'per_person',
      );
      expect(formatPricingFrom(chef), 'From EUR 450 per person');
    });

    test('per_experience unit label', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        priceOnRequest: false,
        pricingFrom: 2500,
        pricingCurrency: 'USD',
        pricingUnit: 'per_experience',
      );
      expect(formatPricingFrom(chef), 'From USD 2500 per experience');
    });

    test('fractional amount keeps two decimals', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        priceOnRequest: false,
        pricingFrom: 449.5,
        pricingCurrency: 'EUR',
      );
      expect(formatPricingFrom(chef), 'From EUR 449.50');
    });

    test('no currency/unit -> still shows the amount, no invented symbol', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        priceOnRequest: false,
        pricingFrom: 450,
      );
      expect(formatPricingFrom(chef), 'From 450');
    });
  });

  group('PrivateChefExperienceSection', () {
    Widget wrap(PrivateChef chef) => MaterialApp(
      home: Scaffold(body: PrivateChefExperienceSection(chef: chef)),
    );

    testWidgets('a chef with nothing to show renders nothing (no heading)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_bareChef));
      expect(find.text('THE EXPERIENCE'), findsNothing);
    });

    testWidgets('service area renders as "Available across X."', (
      tester,
    ) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        serviceAreaText: 'The Netherlands and Belgium',
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.text('THE EXPERIENCE'), findsOneWidget);
      expect(
        find.text('Available across The Netherlands and Belgium.'),
        findsOneWidget,
      );
    });

    testWidgets('travel_available with no service area shows the fallback '
        'line', (tester) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        travelAvailable: true,
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.text('Available for travel.'), findsOneWidget);
    });

    testWidgets('wine pairing available with no note', (tester) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        winePairingAvailable: true,
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.text('Wine pairing available.'), findsOneWidget);
    });

    testWidgets('wine pairing available with a note appends it', (
      tester,
    ) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        winePairingAvailable: true,
        wineNote: 'works with a sommelier',
      );
      await tester.pumpWidget(wrap(chef));
      expect(
        find.text('Wine pairing available — works with a sommelier'),
        findsOneWidget,
      );
    });

    testWidgets('wine_pairing_available false renders no wine line at all '
        '(omission, not a negative statement)', (tester) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        serviceAreaText: 'Anywhere',
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.textContaining('Wine'), findsNothing);
    });

    testWidgets('price on request shows the restrained line', (tester) async {
      final chef = PrivateChef(id: 'c1', slug: 'chef', displayName: 'Chef');
      await tester.pumpWidget(wrap(chef));
      expect(find.text('Price on request.'), findsOneWidget);
    });

    testWidgets('languages render as a single sentence', (tester) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        languages: ['English', 'Dutch'],
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.text('Speaks English, Dutch.'), findsOneWidget);
    });

    testWidgets('personalization note renders as its own line verbatim', (
      tester,
    ) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        personalizationNote: 'Menus are tailored to the table.',
      );
      await tester.pumpWidget(wrap(chef));
      expect(find.text('Menus are tailored to the table.'), findsOneWidget);
    });
  });
}
