// Covers DeleteAccountScreen (Account Deletion / App Store readiness
// addendum to Navigation & Information Architecture V2 UI Refinement) —
// a real, destructive flow, not a Coming Soon placeholder. Both
// deleteAccount and signOut are constructor-injected (hand-rolled fakes,
// no mocking framework), so — unlike most Supabase-eager screens in this
// app — the REAL widget is pumped directly; it never touches Supabase
// unless both injected callbacks are omitted (production default only).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/profile/delete_account_screen.dart';

Future<void> _pumpPushed(
  WidgetTester tester, {
  required Future<void> Function() deleteAccount,
  required Future<void> Function() signOut,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeleteAccountScreen(
                    deleteAccount: deleteAccount,
                    signOut: signOut,
                  ),
                ),
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
  group('DeleteAccountScreen', () {
    testWidgets('renders a restrained explanation — warning icon, title, '
        "body copy, and never claims deletion already happened", (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        deleteAccount: () async {},
        signOut: () async {},
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Delete your account'), findsOneWidget);
      expect(find.textContaining("can't be undone"), findsOneWidget);
      expect(find.text('Delete my account'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('first tap does not delete anything — opens a confirmation '
        'dialog instead', (tester) async {
      var deleteCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async => deleteCalls++,
        signOut: () async {},
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(deleteCalls, 0);
    });

    testWidgets('Cancel in the confirmation dialog leaves the account '
        'untouched', (tester) async {
      var deleteCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async => deleteCalls++,
        signOut: () async {},
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      // Two 'Cancel' texts now exist (screen-level + dialog) — tap the
      // dialog's.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);
      expect(find.text('Delete your account'), findsOneWidget); // still here
    });

    testWidgets('screen-level Cancel pops without deleting anything', (
      tester,
    ) async {
      var deleteCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async => deleteCalls++,
        signOut: () async {},
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Delete your account'), findsNothing);
    });

    testWidgets('the final confirmation invokes the deletion abstraction '
        'exactly once', (tester) async {
      var deleteCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async => deleteCalls++,
        signOut: () async {},
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 1);
    });

    testWidgets('success signs the user out and returns to the '
        'unauthenticated entry (pops to root)', (tester) async {
      var signOutCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async {},
        signOut: () async => signOutCalls++,
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(signOutCalls, 1);
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Delete your account'), findsNothing);
    });

    testWidgets('backend failure leaves the user authenticated, shows a '
        'restrained error, and never falsely claims success', (
      tester,
    ) async {
      var signOutCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async => throw Exception('function not found'),
        signOut: () async => signOutCalls++,
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(signOutCalls, 0);
      expect(find.text('Root'), findsNothing); // never popped
      expect(
        find.text('Could not delete your account. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('function not found'), findsNothing);
    });

    testWidgets('after a failure, the button is re-enabled and a retry can '
        'succeed', (tester) async {
      var attempt = 0;
      var signOutCalls = 0;
      await _pumpPushed(
        tester,
        deleteAccount: () async {
          attempt++;
          if (attempt == 1) throw Exception('transient failure');
        },
        signOut: () async => signOutCalls++,
      );
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(attempt, 1);
      expect(find.text('Delete my account'), findsOneWidget); // re-enabled

      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(attempt, 2);
      expect(signOutCalls, 1);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('the destructive action is error-tinted, never gold, never '
        'a filled/loud primary button', (tester) async {
      await _pumpPushed(
        tester,
        deleteAccount: () async {},
        signOut: () async {},
      );
      final button = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(button.style?.side?.resolve({}), isNotNull);
      final label = tester.widget<Text>(find.text('Delete my account'));
      expect(label.style?.color, AppColors.error);
      expect(label.style?.color, isNot(AppColors.gold));
    });
  });
}
