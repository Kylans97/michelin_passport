// Wines on a visit (visit_wines, 20261101330000): what a row says, how it
// reads on a review, and the short sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/visit_wine_repository.dart';
import 'package:michelin_passport/features/visits/widgets/visit_wines.dart';
import 'package:michelin_passport/models/visit_wine.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('VisitWine', () {
    test('an empty wine is empty; any one field is enough', () {
      expect(const VisitWine().isEmpty, isTrue);
      expect(const VisitWine(producer: 'A').isEmpty, isFalse);
      expect(const VisitWine(vintage: 2015).isEmpty, isFalse);
      expect(const VisitWine(nonVintage: true).isEmpty, isFalse);
      expect(const VisitWine(size: WineSize.glass).isEmpty, isFalse);
    });

    test('no year noted is not the same as no year', () {
      expect(const VisitWine(wineName: 'A').yearLabel, isNull);
      expect(const VisitWine(nonVintage: true).yearLabel, 'NV');
      expect(const VisitWine(vintage: 2015).yearLabel, '2015');
    });

    test('title and subtitle use what is there', () {
      const full = VisitWine(
        producer: 'Domaine',
        wineName: 'Cuvee',
        size: WineSize.magnum,
      );
      expect(full.title, 'Cuvee');
      expect(full.subtitle, 'Domaine · Magnum');
      const producerOnly = VisitWine(producer: 'Domaine', size: WineSize.glass);
      expect(producerOnly.title, 'Domaine');
      expect(producerOnly.subtitle, 'Glass');
      const sizeOnly = VisitWine(size: WineSize.half);
      expect(sizeOnly.title, 'Half');
      expect(sizeOnly.subtitle, isNull);
    });

    test('round-trips through a row', () {
      final w = VisitWine.fromJson({
        'id': 'x',
        'producer': 'Domaine',
        'wine_name': null,
        'vintage': 2008,
        'non_vintage': false,
        'bottle_size': 'magnum',
      });
      expect(w.size, WineSize.magnum);
      expect(w.toRow(), {
        'producer': 'Domaine',
        'wine_name': null,
        'vintage': 2008,
        'non_vintage': false,
        'bottle_size': 'magnum',
      });
    });

    test('a year must be plausible, and may be empty', () {
      final now = DateTime(2026, 11, 4);
      expect(isValidWineYear(null, now: now), isTrue);
      expect(isValidWineYear(2015, now: now), isTrue);
      expect(isValidWineYear(2027, now: now), isTrue);
      expect(isValidWineYear(2028, now: now), isFalse);
      expect(isValidWineYear(201, now: now), isFalse);
    });

    test('suggestions match, skip the exact name and stop at the limit', () {
      const known = [
        'Domaine A',
        'Domaine B',
        'Maison C',
        'domaine a',
        'Domaine D',
        'Domaine E',
      ];
      expect(matchingWineNames(known, ''), isEmpty);
      expect(matchingWineNames(known, 'Domaine A'), isEmpty);
      expect(matchingWineNames(known, 'mais'), ['Maison C']);
      expect(matchingWineNames(known, 'dom'), hasLength(3));
    });

    test('names from the chosen producer come first', () {
      const s = WineSuggestions(
        wineNames: ['Other'],
        wineNamesByProducer: {
          'Domaine': {'Cuvee'},
        },
      );
      expect(s.namesFor('Domaine').first, 'Cuvee');
      expect(s.namesFor('Unknown'), ['Other']);
    });
  });

  group('WineList', () {
    testWidgets('reads like a wine list', (tester) async {
      await tester.pumpWidget(
        _host(
          const WineList(
            wines: [
              VisitWine(
                producer: 'Domaine',
                wineName: 'Cuvee',
                vintage: 2015,
                size: WineSize.bottle,
              ),
              VisitWine(
                producer: 'Maison',
                wineName: 'Reserve',
                nonVintage: true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('2015'), findsOneWidget);
      expect(find.text('NV'), findsOneWidget);
      expect(find.text('Cuvee'), findsOneWidget);
      expect(find.text('Domaine · Bottle'), findsOneWidget);
    });
  });

  group('WineSheet', () {
    Future<List<VisitWine>> pumpSheet(WidgetTester tester) async {
      final saved = <VisitWine>[];
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          WineSheet(
            onSave: (w) async {
              saved.add(w);
              return true;
            },
          ),
        ),
      );
      return saved;
    }

    testWidgets('nothing filled in means nothing to add', (tester) async {
      final saved = await pumpSheet(tester);
      await tester.tap(find.text('Add and another'));
      await tester.pump();
      expect(saved, isEmpty);
    });

    testWidgets('one field is enough, and the sheet clears for the next', (
      tester,
    ) async {
      final saved = await pumpSheet(tester);
      await tester.tap(find.text('Magnum'));
      await tester.pump();
      await tester.tap(find.text('Add and another'));
      await tester.pumpAndSettle();
      expect(saved.single.size, WineSize.magnum);
      expect(saved.single.producer, isNull);
      expect(find.textContaining('1 added'), findsOneWidget);
      await tester.tap(find.text('Add and another'));
      await tester.pump();
      expect(saved, hasLength(1));
    });

    testWidgets('No year and a typed year cancel each other', (tester) async {
      final saved = await pumpSheet(tester);
      await tester.tap(find.text('No year'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), '2015');
      await tester.pump();
      await tester.tap(find.text('Add and another'));
      await tester.pumpAndSettle();
      expect(saved.single.vintage, 2015);
      expect(saved.single.nonVintage, isFalse);
    });

    testWidgets('an impossible year stops the save', (tester) async {
      final saved = await pumpSheet(tester);
      await tester.enterText(find.byType(TextField).at(2), '1234');
      await tester.pump();
      expect(find.text("That year doesn't look right."), findsOneWidget);
      await tester.tap(find.text('Add and another'));
      await tester.pump();
      expect(saved, isEmpty);
    });
  });
}
