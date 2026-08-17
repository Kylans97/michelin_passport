// Covers PrivateChefRow — person-first identity hierarchy, optional
// business name, optional location, image fallback, tap, and the gold
// audit (no gold anywhere in this row).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_row.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Test Chef');

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('PrivateChefRow', () {
    testWidgets('renders display_name as the primary line', (tester) async {
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: _chef, onTap: () {})));
      expect(find.text('Test Chef'), findsOneWidget);
    });

    testWidgets('business_name absent -> no second line rendered', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: _chef, onTap: () {})));
      expect(find.textContaining('Catering'), findsNothing);
    });

    testWidgets(
      'business_name present renders as a clearly subordinate second line, '
      'person-first (display_name comes first, not last)',
      (tester) async {
        const chef = PrivateChef(
          id: 'c1',
          slug: 'lucas',
          displayName: 'Lucas',
          businessName: 'Test Catering',
        );
        await tester.pumpWidget(
          _wrap(PrivateChefRow(chef: chef, onTap: () {})),
        );
        expect(find.text('Lucas'), findsOneWidget);
        expect(find.text('Test Catering'), findsOneWidget);

        final nameFinder = find.text('Lucas');
        final businessFinder = find.text('Test Catering');
        final nameY = tester.getTopLeft(nameFinder).dy;
        final businessY = tester.getTopLeft(businessFinder).dy;
        expect(nameY, lessThan(businessY));
      },
    );

    testWidgets('home city + country render as one location line', (
      tester,
    ) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'Lucas',
        homeCity: 'Breda',
        homeCountryCode: 'NL',
      );
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: chef, onTap: () {})));
      expect(find.text('Breda, NL'), findsOneWidget);
    });

    testWidgets('no home city/country -> no location line', (tester) async {
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: _chef, onTap: () {})));
      expect(find.textContaining('NL'), findsNothing);
    });

    testWidgets('null profile_image_url falls back to CsImagePlaceholder', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: _chef, onTap: () {})));
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(PrivateChefRow(chef: _chef, onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(PrivateChefRow));
      expect(tapped, isTrue);
    });

    testWidgets('gold audit: no gold color anywhere in this row', (
      tester,
    ) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'Lucas',
        businessName: 'Test Catering',
        homeCity: 'Breda',
        homeCountryCode: 'NL',
      );
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: chef, onTap: () {})));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow with a long name/business name', (
      tester,
    ) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'A Genuinely Very Long Private Chef Display Name Indeed',
        businessName: 'An Equally Long Catering Business Name For Testing',
        homeCity: 'Breda',
        homeCountryCode: 'NL',
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_wrap(PrivateChefRow(chef: chef, onTap: () {})));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: PrivateChefRow(chef: _chef, onTap: () {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
