// Covers ChangePasswordScreen — the ACCOUNT-section counterpart to
// DeleteAccountScreen for a logged-in user changing their own password.
// changePassword is constructor-injected (same hand-rolled-fake, no
// mocking-framework convention as DeleteAccountScreen's own
// deleteAccount/signOut), so — unlike most Supabase-eager screens in this
// app — the REAL widget is pumped directly; it never touches Supabase
// unless the injected callback is omitted (production default only).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/features/profile/change_password_screen.dart';

typedef _ChangePasswordCall =
    ({String currentPassword, String newPassword});

Future<void> _pumpPushed(
  WidgetTester tester, {
  required Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  changePassword,
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
                  builder: (_) =>
                      ChangePasswordScreen(changePassword: changePassword),
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

Future<void> _fillFields(
  WidgetTester tester, {
  String current = 'oldpassword',
  String next = 'newpassword123',
  String? confirm,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), current); // Current password
  await tester.enterText(fields.at(1), next); // New password
  await tester.enterText(fields.at(2), confirm ?? next); // Confirm
}

void main() {
  group('ChangePasswordScreen', () {
    testWidgets('renders the icon, title, body copy, three fields and both '
        'actions', (tester) async {
      await _pumpPushed(tester, changePassword: ({required currentPassword, required newPassword}) async {});
      expect(find.byIcon(Icons.lock_reset_outlined), findsOneWidget);
      expect(find.text('Change password'), findsNWidgets(2)); // title + button
      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('an empty current password blocks submission without '
        'calling changePassword', (tester) async {
      var calls = 0;
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          calls++;
        },
      );
      await _fillFields(tester, current: '');
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pump();
      expect(find.text('Enter your current password'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a new password shorter than 6 characters is rejected by '
        'the same rule SignupScreen uses, without calling changePassword', (
      tester,
    ) async {
      var calls = 0;
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          calls++;
        },
      );
      await _fillFields(tester, next: 'abc12', confirm: 'abc12');
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pump();
      expect(find.text('Minimum 6 characters'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a confirmation that does not match the new password is '
        'rejected without calling changePassword', (tester) async {
      var calls = 0;
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          calls++;
        },
      );
      await _fillFields(tester, next: 'newpassword123', confirm: 'somethingelse');
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pump();
      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a valid submission calls changePassword exactly once with '
        'the typed current and new passwords, then shows the success view', (
      tester,
    ) async {
      final calls = <_ChangePasswordCall>[];
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          calls.add((currentPassword: currentPassword, newPassword: newPassword));
        },
      );
      await _fillFields(tester, current: 'oldpassword', next: 'newpassword123');
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();

      expect(calls, [
        (currentPassword: 'oldpassword', newPassword: 'newpassword123'),
      ]);
      expect(find.text('Password changed'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // Other devices being signed out is otherwise invisible — must be
      // stated, not left for someone to discover on their iPad.
      expect(find.textContaining('other devices'), findsOneWidget);
      // The form is gone — no stray field labels left behind.
      expect(find.text('Current password'), findsNothing);
    });

    testWidgets('a wrong current password shows a specific, restrained '
        'error and never shows the success view', (tester) async {
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          throw const AuthException('Current password is incorrect.');
        },
      );
      await _fillFields(tester);
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();

      expect(find.text('Current password is incorrect.'), findsOneWidget);
      expect(find.text('Password changed'), findsNothing);
    });

    testWidgets('an unexpected failure shows a generic message and never '
        'leaks the raw exception', (tester) async {
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          throw Exception('connection reset');
        },
      );
      await _fillFields(tester);
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('connection reset'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('screen-level Cancel pops without calling changePassword', (
      tester,
    ) async {
      var calls = 0;
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {
          calls++;
        },
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('Done on the success view returns to the previous screen', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        changePassword: ({required currentPassword, required newPassword}) async {},
      );
      await _fillFields(tester);
      await tester.ensureVisible(find.text('Change password').last);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Root'), findsOneWidget);
    });
  });
}
