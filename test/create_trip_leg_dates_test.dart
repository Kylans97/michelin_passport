// Regression: a two-destination trip whose legs exactly fill the trip
// (10 Nov – 1 Dec, split 10–20 Nov and 20 Nov – 1 Dec) must save. Drives
// the real Create Trip sheet and its date pickers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/planned_trips_repository.dart';
import 'package:michelin_passport/features/trips/widgets/create_trip_sheet.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/trip_destination.dart';
import 'package:michelin_passport/models/venue_country.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepo extends PlannedTripsRepository {
  _FakeRepo()
    : super(
        SupabaseClient(
          'https://test.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  ({DateTime start, DateTime end})? createdTrip;
  List<TripDestination>? savedLegs;
  ({DateTime start, DateTime end})? savedTripDates;

  @override
  Future<List<VenueCountry>> loadAllCountries() async => const [
    VenueCountry(name: 'France', code: 'FR', flag: ''),
    VenueCountry(name: 'Italy', code: 'IT', flag: ''),
  ];

  @override
  Future<PlannedTrip> createTrip({
    required String userId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required String countryCode,
    String? city,
    String? notes,
  }) async {
    createdTrip = (start: startDate, end: endDate);
    return PlannedTrip(
      id: 't1',
      userId: userId,
      title: title,
      startDate: startDate,
      endDate: endDate,
      countryCode: countryCode,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<void> saveTripDestinations({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required List<TripDestination> destinations,
  }) async {
    savedTripDates = (start: startDate, end: endDate);
    savedLegs = destinations;
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Opens the date picker by tapping [opener], moves to [date]'s month and
/// picks its day.
Future<void> _pick(WidgetTester tester, Finder opener, DateTime date) async {
  await tester.ensureVisible(opener);
  await tester.tap(opener);
  await tester.pumpAndSettle();
  final target = '${_months[date.month - 1]} ${date.year}';
  for (var i = 0; i < 24 && find.text(target).evaluate().isEmpty; i++) {
    final forward = find.byTooltip('Next month');
    final back = find.byTooltip('Previous month');
    // Move toward the target month.
    final shown = find.byWidgetPredicate(
      (w) => w is Text && _months.any((m) => (w.data ?? '').startsWith(m)),
    );
    final label = (tester.widget<Text>(shown.first).data ?? '').split(' ');
    final shownMonth = DateTime(
      int.parse(label[1]),
      _months.indexOf(label[0]) + 1,
    );
    await tester.tap(
      shownMonth.isBefore(DateTime(date.year, date.month)) ? forward : back,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('${date.day}').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a trip split into two legs that exactly fill its dates saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The existing CountryPickerSheet puts ListTiles on a coloured box,
    // which only trips a debug-mode ink assertion; not what's tested here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'ink splashes may be invisible',
      )) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final repo = _FakeRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCreateTripSheet(context, userId: 'u1', repo: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Paris and Rome');
    final start = DateTime(DateTime.now().year, DateTime.now().month + 1, 10);
    final end = start.add(const Duration(days: 21));
    final split = start.add(const Duration(days: 10));

    await _pick(tester, find.text('FROM'), start);
    await _pick(tester, find.text('TO'), end);

    // Destination 1: France.
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('France').last);
    await tester.pumpAndSettle();
    // Destination 2: Italy.
    await tester.ensureVisible(find.text('Add another destination'));
    await tester.tap(find.text('Add another destination'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose a country'));
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italy').last);
    await tester.pumpAndSettle();

    await _pick(tester, find.text('ARRIVE').first, start);
    await _pick(tester, find.text('LEAVE').first, split);
    await _pick(tester, find.text('ARRIVE').last, split);
    await _pick(tester, find.text('LEAVE').last, end);

    await tester.ensureVisible(find.text('Create trip'));
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must fall within'), findsNothing);
    expect(repo.savedLegs, hasLength(2));
    expect(repo.savedLegs!.last.endDate, end);
  });
  testWidgets('same, leaving the trip\'s end date at its default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The existing CountryPickerSheet puts ListTiles on a coloured box,
    // which only trips a debug-mode ink assertion; not what's tested here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'ink splashes may be invisible',
      )) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final repo = _FakeRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCreateTripSheet(context, userId: 'u1', repo: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Paris and Rome');
    // The sheet's default end date — kept, not re-picked.
    final now = DateTime.now();
    final end = DateUtils.dateOnly(now.add(const Duration(days: 33)));
    final start = DateUtils.dateOnly(now.add(const Duration(days: 12)));
    final split = start.add(const Duration(days: 10));

    await _pick(tester, find.text('FROM'), start);

    // Destination 1: France.
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('France').last);
    await tester.pumpAndSettle();
    // Destination 2: Italy.
    await tester.ensureVisible(find.text('Add another destination'));
    await tester.tap(find.text('Add another destination'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose a country'));
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italy').last);
    await tester.pumpAndSettle();

    await _pick(tester, find.text('ARRIVE').first, start);
    await _pick(tester, find.text('LEAVE').first, split);
    await _pick(tester, find.text('ARRIVE').last, split);
    await _pick(tester, find.text('LEAVE').last, end);

    await tester.ensureVisible(find.text('Create trip'));
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must fall within'), findsNothing);
    expect(repo.savedLegs, hasLength(2));
    expect(repo.savedLegs!.last.endDate, end);
  });
  testWidgets('a destination starting on the default first day saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The existing CountryPickerSheet puts ListTiles on a coloured box,
    // which only trips a debug-mode ink assertion; not what's tested here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'ink splashes may be invisible',
      )) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final repo = _FakeRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCreateTripSheet(context, userId: 'u1', repo: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Paris and Rome');
    // The sheet's default end date — kept, not re-picked.
    final now = DateTime.now();
    final end = DateUtils.dateOnly(now.add(const Duration(days: 33)));
    // The sheet's default start date — kept, not re-picked.
    final start = DateUtils.dateOnly(now.add(const Duration(days: 30)));
    final split = start.add(const Duration(days: 1));

    // Destination 1: France.
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('France').last);
    await tester.pumpAndSettle();
    // Destination 2: Italy.
    await tester.ensureVisible(find.text('Add another destination'));
    await tester.tap(find.text('Add another destination'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose a country'));
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italy').last);
    await tester.pumpAndSettle();

    await _pick(tester, find.text('ARRIVE').first, start);
    await _pick(tester, find.text('LEAVE').first, split);
    await _pick(tester, find.text('ARRIVE').last, split);
    await _pick(tester, find.text('LEAVE').last, end);

    await tester.ensureVisible(find.text('Create trip'));
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must fall within'), findsNothing);
    expect(repo.savedLegs, hasLength(2));
    expect(repo.savedLegs!.last.endDate, end);
  });
  testWidgets('editing an existing single-destination trip into two legs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The existing CountryPickerSheet puts ListTiles on a coloured box,
    // which only trips a debug-mode ink assertion; not what's tested here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'ink splashes may be invisible',
      )) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final repo = _FakeRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCreateTripSheet(
                context,
                userId: 'u1',
                repo: repo,
                existingTrip: PlannedTrip(
                  id: 't1',
                  userId: 'u1',
                  title: 'Old',
                  startDate: DateTime.parse('2027-01-04'),
                  endDate: DateTime.parse('2027-01-09'),
                  countryCode: 'FR',
                  createdAt: DateTime(2026),
                  destinations: const [TripDestination(countryCode: 'FR')],
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

    await tester.enterText(find.byType(TextField).first, 'Paris and Rome');
    final now = DateTime.now();
    final start = DateUtils.dateOnly(now.add(const Duration(days: 12)));
    final end = start.add(const Duration(days: 21));
    final split = start.add(const Duration(days: 10));

    await _pick(tester, find.text('FROM'), start);
    await _pick(tester, find.text('TO'), end);

    // Destination 2: Italy.
    await tester.ensureVisible(find.text('Add another destination'));
    await tester.tap(find.text('Add another destination'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose a country'));
    await tester.tap(find.text('Choose a country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italy').last);
    await tester.pumpAndSettle();

    await _pick(tester, find.text('ARRIVE').first, start);
    await _pick(tester, find.text('LEAVE').first, split);
    await _pick(tester, find.text('ARRIVE').last, split);
    await _pick(tester, find.text('LEAVE').last, end);

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must fall within'), findsNothing);
    expect(repo.savedLegs, hasLength(2));
    expect(repo.savedLegs!.last.endDate, end);
  });
}
