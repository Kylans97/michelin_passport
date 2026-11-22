// Editing and deleting an estate visit or a train or ship journey, the way
// a restaurant visit can be (2026-11-22): the update maps, the sheets
// opened on an existing entry, and the row's Edit and Delete.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/l10n/app_locale.dart';
import 'package:michelin_passport/data/repositories/journey_repository.dart';
import 'package:michelin_passport/features/journeys/widgets/confirm_travel_sheet.dart';
import 'package:michelin_passport/features/passport/widgets/own_passport_entry_row.dart';
import 'package:michelin_passport/features/vineyards/widgets/log_estate_visit_sheet.dart';
import 'package:michelin_passport/models/journey.dart';
import 'package:michelin_passport/models/vineyard.dart';
import 'package:michelin_passport/models/vineyard_visit.dart';

const _estate = Vineyard(
  id: 'v1',
  vineyardCode: 'vine_0001',
  name: 'Château Smith Haut Lafitte',
  countryCode: 'FR',
  city: 'Martillac',
  region: 'Bordeaux',
);

final _journey = Journey.fromMap({
  'id': 'j1',
  'journey_code': 'train_002',
  'slug': 'belmond-andean-explorer',
  'kind': 'train',
  'ship_type': null,
  'name': 'Belmond Andean Explorer',
  'status': 'operating',
  'first_departure_on': null,
  'summary': null,
  'cabins_text': null,
  'guest_capacity': null,
  'dining_text': null,
  'official_url': null,
  'primary_country_code': 'PE',
  'regions_text': null,
  'country_name': 'Peru',
  'flag_emoji': null,
  'operator_code': 'op_001',
  'operator_name': 'Belmond',
  'operator_website_url': null,
  'route_count': 1,
  'route_country_codes': ['PE'],
});

const _route = JourneyRoute(
  id: 'r1',
  routeCode: 'train_002_r01',
  name: 'Peruvian Highlands',
  fromPlace: 'Cusco',
  toPlace: 'Arequipa',
  fromCountryCode: 'PE',
  nights: 2,
);

/// Opens [open] from a button and hands back what the sheet returned.
Future<T?> _openFrom<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) open,
) async {
  T? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('update maps', () {
    test('an estate visit writes every edited field and clears an emptied '
        'note', () {
      expect(
        buildVineyardVisitUpdate(
          visitedOn: DateTime(2019, 6, 2),
          activities: {VineyardActivity.lunch, VineyardActivity.tasting},
          comment: '  ',
          friendsVisible: true,
        ),
        {
          'visited_on': '2019-06-02',
          'activities': ['tasting', 'lunch'],
          'comment': null,
          'visibility': 'friends',
        },
      );
    });

    test('a travel clears a removed route and arrival, and never touches '
        'its source', () {
      final row = buildJourneyTravelUpdate(departedOn: DateTime(2019, 3, 4));
      expect(row, {
        'route_id': null,
        'departed_on': '2019-03-04',
        'arrived_on': null,
        'visibility': 'private',
      });
      expect(row.containsKey('source'), isFalse);
    });
  });

  testWidgets('the estate sheet opens on an existing visit and saves it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    EstateVisitInput? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => saved = await showLogEstateVisitSheet(
                context,
                vineyard: _estate,
                initial: VineyardVisit(
                  id: 'vv1',
                  vineyardId: 'v1',
                  visitedOn: DateTime(2019, 6, 2),
                  activities: const {VineyardActivity.tasting},
                  comment: 'The 2015 white',
                  friendsVisible: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Your visit'), findsOneWidget);
    expect(find.text('2 June 2019'), findsOneWidget);
    expect(find.text('The 2015 white'), findsOneWidget);
    await tester.tap(find.text('Lunch'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved!.visitedOn, DateTime(2019, 6, 2));
    expect(saved!.activities, {
      VineyardActivity.tasting,
      VineyardActivity.lunch,
    });
    expect(saved!.comment, 'The 2015 white');
    expect(saved!.friendsVisible, isTrue);
  });

  testWidgets('the travel sheet opens on an existing travel and saves it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const SizedBox());
    ConfirmedTravelInput? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => saved = await showConfirmTravelSheet(
                context,
                journey: _journey,
                routes: const [_route],
                initial: JourneyTravel(
                  id: 't1',
                  journeyId: 'j1',
                  routeId: 'r1',
                  departedOn: DateTime(2019, 3, 4),
                  arrivedOn: DateTime(2019, 3, 6),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Your journey'), findsOneWidget);
    expect(find.textContaining('Peruvian Highlands'), findsOneWidget);
    expect(find.text('4 March 2019'), findsOneWidget);
    expect(find.text('6 March 2019'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved!.route, _route);
    expect(saved!.departedOn, DateTime(2019, 3, 4));
    expect(saved!.arrivedOn, DateTime(2019, 3, 6));
    expect(saved!.visibility, JourneyTravelVisibility.private);
  });

  testWidgets('a new entry still reads as adding one', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await _openFrom(
      tester,
      (context) => showLogEstateVisitSheet(context, vineyard: _estate),
    );
    expect(find.text('I visited this estate'), findsOneWidget);
    expect(find.text('Add to my Passport'), findsOneWidget);
  });

  group('OwnPassportEntryRow', () {
    Future<List<String>> pumpRow(WidgetTester tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnPassportEntryRow(
              text: '2 June 2019 · tasting',
              editLabel: 'Edit visit',
              deleteLabel: 'Delete visit',
              onEdit: () => calls.add('edit'),
              onDelete: () => calls.add('delete'),
            ),
          ),
        ),
      );
      return calls;
    }

    testWidgets('tapping the line edits it', (tester) async {
      final calls = await pumpRow(tester);
      await tester.tap(find.text('2 June 2019 · tasting'));
      expect(calls, ['edit']);
    });

    testWidgets('the menu offers Edit and Delete', (tester) async {
      final calls = await pumpRow(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Edit visit'), findsOneWidget);
      await tester.tap(find.text('Delete visit'));
      await tester.pumpAndSettle();
      expect(calls, ['delete']);
    });
  });

  testWidgets('deleting asks first, and Cancel keeps the entry', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answer = await confirmDeletePassportEntry(
                context,
                title: 'Delete this visit?',
                body: 'This visit and its stamp leave your Passport.',
                actionLabel: 'Delete visit',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this visit?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('the app date picker reads day month year', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2019, 6, 2),
                firstDate: DateTime(2006),
                lastDate: DateTime(2026, 11, 22),
                initialEntryMode: DatePickerEntryMode.input,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The typed date is day first, never the American month first.
    expect(find.text('02/06/2019'), findsOneWidget);
    expect(find.text('06/02/2019'), findsNothing);
  });
}
