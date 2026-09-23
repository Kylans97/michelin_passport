// Covers the "report a missing restaurant/hotel/event" sheet.
// submitReport is constructor-injected on the PUBLIC
// showReportMissingListingSheet function (not only the private widget) —
// see that function's own doc comment for why: a test file can never
// reference `_ReportMissingListingSheet` directly across Dart's per-file
// privacy boundary, so the seam has to live on the function it's actually
// possible to call from here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/missing_listing_repository.dart';
import 'package:michelin_passport/features/reports/widgets/report_missing_listing_sheet.dart';

typedef _SubmitCall =
    ({
      MissingListingSubjectType subjectType,
      String name,
      String city,
      String message,
      String? reporterRole,
      String? reporterContact,
    });

Future<void> _openSheet(
  WidgetTester tester, {
  required String initialQuery,
  required Future<void> Function({
    required MissingListingSubjectType subjectType,
    required String name,
    required String city,
    required String message,
    String? reporterRole,
    String? reporterContact,
  })
  submitReport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showReportMissingListingSheet(
                context,
                initialQuery: initialQuery,
                submitReport: submitReport,
              ),
              child: const Text('Root'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Root'));
  await tester.pumpAndSettle();
}

void main() {
  group('report missing listing sheet', () {
    testWidgets('renders the type choices, Name pre-filled from the '
        'search term, City, the message field and the submit button', (
      tester,
    ) async {
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async {},
      );
      expect(find.text('Restaurant'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Flore Amsterdam'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.byKey(const Key('missingListingMessageField')), findsOneWidget);
      expect(find.text('Send report'), findsOneWidget);
      // Not shown until "I work here" is checked.
      expect(find.text('Your role'), findsNothing);
      expect(find.text('Email or phone'), findsNothing);
    });

    testWidgets('submitting with no type selected shows an error and '
        'never calls submitReport', (tester) async {
      var calls = 0;
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async => calls++,
      );
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Choose a type'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('submitting with an empty name (after clearing the '
        'pre-filled value) shows an error, never calls submitReport', (
      tester,
    ) async {
      var calls = 0;
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async => calls++,
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('submitting with a name but no city shows an error, '
        'never calls submitReport', (tester) async {
      var calls = 0;
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async => calls++,
      );
      await tester.tap(find.text('Restaurant'));
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Enter a city'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('submitting with name and city but no message shows the '
        'message-specific error, never calls submitReport — this is the '
        "field the user called the most important one", (tester) async {
      var calls = 0;
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async => calls++,
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(1), 'Amsterdam');
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(
        find.textContaining("Tell us why it belongs"),
        findsOneWidget,
      );
      expect(calls, 0);
    });

    testWidgets('a fully valid submission without "I work here" calls '
        'submitReport with null role/contact, then closes and shows a '
        'confirmation on the caller context', (tester) async {
      final calls = <_SubmitCall>[];
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async {
          calls.add((
            subjectType: subjectType,
            name: name,
            city: city,
            message: message,
            reporterRole: reporterRole,
            reporterContact: reporterContact,
          ));
        },
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(1), 'Amsterdam');
      await tester.enterText(
        find.byKey(const Key('missingListingMessageField')),
        'Four-hands dinner series, sells out every month.',
      );
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(calls, [
        (
          subjectType: MissingListingSubjectType.restaurant,
          name: 'Flore Amsterdam',
          city: 'Amsterdam',
          message: 'Four-hands dinner series, sells out every month.',
          reporterRole: null,
          reporterContact: null,
        ),
      ]);
      // Sheet closed and the Root screen's SnackBar confirmation shows.
      expect(find.text('Root'), findsOneWidget);
      expect(find.textContaining("we'll take a look"), findsOneWidget);
    });

    testWidgets('checking "I work here" reveals Role/Contact and the '
        'contact-use disclosure line', (tester) async {
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async {},
      );
      await tester.tap(find.text('I work here'));
      await tester.pump();
      expect(find.text('Your role'), findsOneWidget);
      expect(find.text('Email or phone'), findsOneWidget);
      expect(
        find.text(
          "We'll only use this to contact you about this report.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('"I work here" checked but role/contact left empty shows '
        'an error, never calls submitReport', (tester) async {
      var calls = 0;
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async => calls++,
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(1), 'Amsterdam');
      await tester.enterText(
        find.byKey(const Key('missingListingMessageField')),
        'Four-hands dinner series.',
      );
      await tester.tap(find.text('I work here'));
      await tester.pump();
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(
        find.text('Enter your role and a way to reach you'),
        findsOneWidget,
      );
      expect(calls, 0);
    });

    testWidgets('a valid submission WITH "I work here" passes the typed '
        'role and contact through', (tester) async {
      final calls = <_SubmitCall>[];
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async {
          calls.add((
            subjectType: subjectType,
            name: name,
            city: city,
            message: message,
            reporterRole: reporterRole,
            reporterContact: reporterContact,
          ));
        },
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(1), 'Amsterdam');
      await tester.enterText(
        find.byKey(const Key('missingListingMessageField')),
        'Four-hands dinner series.',
      );
      await tester.tap(find.text('I work here'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), 'Sommelier');
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'sommelier@flore.example',
      );
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(calls, [
        (
          subjectType: MissingListingSubjectType.restaurant,
          name: 'Flore Amsterdam',
          city: 'Amsterdam',
          message: 'Four-hands dinner series.',
          reporterRole: 'Sommelier',
          reporterContact: 'sommelier@flore.example',
        ),
      ]);
    });

    testWidgets('a backend failure shows a generic message and never '
        'leaks the raw exception', (tester) async {
      await _openSheet(
        tester,
        initialQuery: 'Flore Amsterdam',
        submitReport: ({
          required subjectType,
          required name,
          required city,
          required message,
          reporterRole,
          reporterContact,
        }) async {
          throw Exception('connection reset');
        },
      );
      await tester.tap(find.text('Restaurant'));
      await tester.enterText(find.byType(TextFormField).at(1), 'Amsterdam');
      await tester.enterText(
        find.byKey(const Key('missingListingMessageField')),
        'Four-hands dinner series.',
      );
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not send this report. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('connection reset'), findsNothing);
      // Never closed on failure.
      expect(find.text('Send report'), findsOneWidget);
    });
  });
}
