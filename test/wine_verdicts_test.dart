// Wine verdicts and wines kept without a visit (20261101630000): what a
// row says, what is written to which table, how a wine reads with its
// verdict, the sheet's new parts, and the estate page's line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/visit_wine_repository.dart';
import 'package:michelin_passport/features/passport/models/cellar.dart';
import 'package:michelin_passport/features/vineyards/vineyard_detail_screen.dart';
import 'package:michelin_passport/features/visits/widgets/visit_wines.dart';
import 'package:michelin_passport/models/visit_wine.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('WineVerdict', () {
    test('reads its three database values and nothing else', () {
      expect(WineVerdict.fromDb('again'), WineVerdict.again);
      expect(WineVerdict.fromDb('fine'), WineVerdict.fine);
      expect(WineVerdict.fromDb('not_for_me'), WineVerdict.notForMe);
      expect(WineVerdict.fromDb(null), isNull);
      expect(WineVerdict.fromDb('great'), isNull);
    });

    test('labels are the plan\'s three answers', () {
      expect(WineVerdict.values.map((v) => v.label), [
        'Would drink again',
        'It was fine',
        'Not for me',
      ]);
    });
  });

  group('A visit\'s wine', () {
    test('without a verdict sends no verdict columns, so it saves on a '
        'database before the migration', () {
      final row = const VisitWine(producer: 'Tempier').toRow();
      expect(row.containsKey('verdict'), isFalse);
      expect(row.containsKey('tasting_note'), isFalse);
    });

    test('sends its verdict and note; a cleared verdict sends null', () {
      final row = const VisitWine(
        producer: 'Tempier',
        verdict: WineVerdict.again,
        tastingNote: 'Dark cherry.',
      ).toRow();
      expect(row['verdict'], 'again');
      expect(row['tasting_note'], 'Dark cherry.');
      final cleared = const VisitWine(
        producer: 'Tempier',
      ).toRow(withVerdict: true);
      expect(cleared['verdict'], isNull);
      expect(cleared.containsKey('verdict'), isTrue);
      expect(cleared['tasting_note'], isNull);
    });

    test('never writes the kept-wine columns', () {
      final row = const VisitWine(
        producer: 'Tempier',
        setting: WineSetting.home,
      ).toRow();
      expect(row.containsKey('setting'), isFalse);
      expect(row.containsKey('drunk_on'), isFalse);
    });

    test('reads verdict and note from a row', () {
      final w = VisitWine.fromJson({
        'id': 'w1',
        'producer': 'Tempier',
        'verdict': 'not_for_me',
        'tasting_note': 'Too oaky.',
      });
      expect(w.verdict, WineVerdict.notForMe);
      expect(w.tastingNote, 'Too oaky.');
      expect(w.wouldDrinkAgain, isFalse);
      expect(w.setting, isNull);
    });
  });

  group('A wine kept without a visit', () {
    test('writes every cellar_wines column, home by default', () {
      final row = VisitWine(
        producer: 'Tempier',
        wineName: 'Bandol Rosé',
        vintage: 2022,
        verdict: WineVerdict.again,
        drunkOn: DateTime(2026, 11, 5),
      ).toCellarRow();
      expect(row['setting'], 'home');
      expect(row['drunk_on'], '2026-11-05');
      expect(row['verdict'], 'again');
      expect(row['vineyard_id'], isNull);
      expect(row.containsKey('vineyard_id'), isTrue);
      expect(row.containsKey('visit_id'), isFalse);
    });

    test('round-trips setting, place and day', () {
      final w = VisitWine.fromJson({
        'id': 'k1',
        'wine_name': 'Riesling',
        'setting': 'elsewhere',
        'place': 'Bar Brutal',
        'drunk_on': '2026-10-31',
      });
      expect(w.setting, WineSetting.elsewhere);
      expect(w.place, 'Bar Brutal');
      expect(w.drunkOn, DateTime(2026, 10, 31));
    });

    test('says where it was drunk under its name', () {
      expect(
        const VisitWine(
          producer: 'Tempier',
          wineName: 'Rosé',
          setting: WineSetting.home,
        ).subtitle,
        'Tempier · At home',
      );
      expect(
        const VisitWine(
          wineName: 'Rosé',
          setting: WineSetting.elsewhere,
          place: 'Bar Brutal',
        ).subtitle,
        'Bar Brutal',
      );
    });

    test('has no visit, and groups in the Cellar like any other wine', () {
      const kept = CellarWine(wine: VisitWine(wineName: 'Rosé'));
      expect(kept.isKeptWithoutVisit, isTrue);
      final cellar = buildCellar([kept]);
      expect(cellar.unlinked.single.wine.wineName, 'Rosé');
    });
  });

  group('WineList with verdicts', () {
    testWidgets('shows Again in claret, the note in italics', (tester) async {
      await tester.pumpWidget(
        _host(
          const WineList(
            wines: [
              VisitWine(
                wineName: 'Bandol Rouge',
                verdict: WineVerdict.again,
                tastingNote: 'Dark cherry, garrigue.',
              ),
              VisitWine(wineName: 'Cabassaou', verdict: WineVerdict.fine),
              VisitWine(wineName: 'Plain'),
            ],
          ),
        ),
      );
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Fine'), findsOneWidget);
      expect(find.text('Dark cherry, garrigue.'), findsOneWidget);
    });
  });

  group('WineSheet', () {
    testWidgets('asks how it was, and saves the verdict and note', (
      tester,
    ) async {
      VisitWine? saved;
      await tester.pumpWidget(
        _host(
          WineSheet(
            onSave: (w) async {
              saved = w;
              return true;
            },
          ),
        ),
      );
      expect(find.text('How was it?'), findsOneWidget);
      expect(find.text('Where did you drink it?'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Tempier');
      await tester.ensureVisible(find.text('Would drink again'));
      await tester.tap(find.text('Would drink again'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Dark cherry.');
      await tester.pump();
      final add = find.widgetWithText(ElevatedButton, 'Add');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pump();
      expect(saved?.verdict, WineVerdict.again);
      expect(saved?.tastingNote, 'Dark cherry.');
      expect(saved?.setting, isNull);
    });

    testWidgets('a kept wine also asks where and when, home by default', (
      tester,
    ) async {
      VisitWine? saved;
      await tester.pumpWidget(
        _host(
          WineSheet(
            keptWithoutVisit: true,
            onSave: (w) async {
              saved = w;
              return true;
            },
          ),
        ),
      );
      expect(find.text('Where did you drink it?'), findsOneWidget);
      expect(find.text('Pick a day'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Tempier');
      await tester.pump();
      final add = find.widgetWithText(ElevatedButton, 'Add');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pump();
      expect(saved?.setting, WineSetting.home);
      expect(saved?.place, isNull);
    });

    testWidgets('tapping the chosen verdict again clears it', (tester) async {
      VisitWine? saved;
      await tester.pumpWidget(
        _host(
          WineSheet(
            initial: const VisitWine(
              id: 'w1',
              producer: 'Tempier',
              verdict: WineVerdict.fine,
            ),
            onSave: (w) async {
              saved = w;
              return true;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.text('It was fine'));
      await tester.tap(find.text('It was fine'));
      await tester.pump();
      final save = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(saved, isNotNull);
      expect(saved!.verdict, isNull);
    });
  });

  test('the estate page line counts wines the member would drink again', () {
    expect(wouldDrinkAgainLine(1), "You'd drink one of their wines again");
    expect(wouldDrinkAgainLine(2), "You'd drink 2 of their wines again");
  });
}
