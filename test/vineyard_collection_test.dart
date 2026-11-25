// Official classifications in Guides (product owner, 2026-11-25): a
// Bordeaux Classifications card with one row per list, each list in class
// order with the class under each estate. Estate names here are made up.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/app_theme.dart';
import 'package:michelin_passport/features/guides/guides_screen.dart';
import 'package:michelin_passport/models/vineyard.dart';
import 'package:michelin_passport/models/vineyard_recognition.dart';

Vineyard _v(String id, String name) =>
    Vineyard(id: id, vineyardCode: 'vine_$id', name: name, countryCode: 'FR');

VineyardRecognition _r(String id, String scheme, String label, int order) =>
    VineyardRecognition(
      vineyardId: id,
      scheme: scheme,
      classLabel: label,
      classOrder: order,
      edition: 1855,
    );

void main() {
  final byId = {
    for (final v in [
      _v('b', 'Château Beta'),
      _v('c', 'Château Gamma'),
      _v('d', 'Château Delta'),
    ])
      v.id: v,
  };

  group('classifiedEstates', () {
    test('one list only, by class then name, the class as the note', () {
      final entries = classifiedEstates(
        scheme: 'bordeaux_1855_medoc',
        recognitions: [
          _r('c', 'saint_emilion', 'Grand Cru Classé', 3),
          _r('d', 'bordeaux_1855_medoc', 'Troisième Cru', 3),
          _r('c', 'bordeaux_1855_medoc', 'Troisième Cru', 3),
          _r('b', 'bordeaux_1855_medoc', 'Premier Cru', 1),
        ],
        byId: byId,
      );
      expect(entries.map((e) => e.vineyard.name), [
        'Château Beta',
        'Château Delta',
        'Château Gamma',
      ]);
      expect(entries.first.note, 'Premier Cru');
      expect(entries.first.marker, '');
    });

    test('an estate the app could not load is left out', () {
      final entries = classifiedEstates(
        scheme: 'graves_1959',
        recognitions: [_r('zzz', 'graves_1959', 'Cru Classé de Graves', 1)],
        byId: byId,
      );
      expect(entries, isEmpty);
    });
  });

  group('Guides, Bordeaux Classifications card', () {
    Future<void> pump(WidgetTester tester, Set<String> schemes) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.mantelier,
          home: GuidesScreen(loadClassificationSchemes: () async => schemes),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a row for each list that has estates, in fixed order', (
      tester,
    ) async {
      await pump(tester, {'saint_emilion', 'bordeaux_1855_medoc'});
      await tester.scrollUntilVisible(
        find.text('Saint-Émilion'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('BORDEAUX CLASSIFICATIONS'), findsOneWidget);
      expect(find.text('1855, Médoc'), findsOneWidget);
      expect(find.text('Saint-Émilion'), findsOneWidget);
      expect(find.text('Graves'), findsNothing);
      expect(
        tester.getTopLeft(find.text('1855, Médoc')).dy,
        lessThan(tester.getTopLeft(find.text('Saint-Émilion')).dy),
      );
    });

    testWidgets('stays away while no list has estates', (tester) async {
      await pump(tester, const {});
      expect(find.text('BORDEAUX CLASSIFICATIONS'), findsNothing);
    });
  });

  test('a classified estate shows its village, else its region', () {
    const withVillage = Vineyard(
      id: 'p',
      vineyardCode: 'vine_9001',
      name: 'Château Test',
      countryCode: 'FR',
      countryName: 'France',
      region: 'Bordeaux',
      communeName: 'Pauillac',
    );
    const without = Vineyard(
      id: 'q',
      vineyardCode: 'vine_9002',
      name: 'Château Test Deux',
      countryCode: 'FR',
      countryName: 'France',
      region: 'Bordeaux',
    );
    expect(withVillage.villageLine, 'Pauillac, France');
    expect(without.villageLine, 'Bordeaux, France');
  });
}
