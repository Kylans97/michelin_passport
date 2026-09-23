// Covers ResetPasswordScreen — reached only via AuthGate while
// _passwordRecoveryPending is true (see its own doc comment), never pushed
// via Navigator, so there is deliberately no "success" state to assert on
// here: a successful completePasswordRecovery() signs the session out, and
// it's AuthGate's own signedOut handling (covered in auth_gate_test.dart)
// that takes it from there back to LoginScreen. completePasswordRecovery/
// cancel are constructor-injected (same hand-rolled-fake convention as
// every other auth-adjacent screen in this app), so the REAL widget is
// pumped directly here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/features/auth/reset_password_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _fillFields(
  WidgetTester tester, {
  String next = 'newpassword123',
  String? confirm,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), next); // New password
  await tester.enterText(fields.at(1), confirm ?? next); // Confirm
}

void main() {
  group('ResetPasswordScreen', () {
    testWidgets('renders the icon, title, body copy, two fields and both '
        'actions — no "current password" field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async {},
            cancel: () async {},
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_reset_outlined), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('Current password'), findsNothing);
      expect(find.text('Set new password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('a new password shorter than 6 characters is rejected by '
        "the same PasswordRules SignupScreen/ChangePasswordScreen use, "
        'without calling completePasswordRecovery', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async => calls++,
            cancel: () async {},
          ),
        ),
      );
      await _fillFields(tester, next: 'abc12', confirm: 'abc12');
      await tester.ensureVisible(find.text('Set new password'));
      await tester.tap(find.text('Set new password'));
      await tester.pump();
      expect(find.text('Minimum 6 characters'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a confirmation that does not match the new password is '
        'rejected without calling completePasswordRecovery', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async => calls++,
            cancel: () async {},
          ),
        ),
      );
      await _fillFields(tester, next: 'newpassword123', confirm: 'different');
      await tester.ensureVisible(find.text('Set new password'));
      await tester.tap(find.text('Set new password'));
      await tester.pump();
      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a valid submission calls completePasswordRecovery exactly '
        'once with the typed new password', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async =>
                calls.add(newPassword),
            cancel: () async {},
          ),
        ),
      );
      await _fillFields(tester, next: 'newpassword123');
      await tester.ensureVisible(find.text('Set new password'));
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(calls, ['newpassword123']);
    });

    testWidgets('a failure shows a restrained error message from the '
        'AuthException', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async {
              throw const AuthException('Recovery link has expired.');
            },
            cancel: () async {},
          ),
        ),
      );
      await _fillFields(tester);
      await tester.ensureVisible(find.text('Set new password'));
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(find.text('Recovery link has expired.'), findsOneWidget);
    });

    testWidgets('an unexpected failure shows a generic message and never '
        'leaks the raw exception', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async {
              throw Exception('connection reset');
            },
            cancel: () async {},
          ),
        ),
      );
      await _fillFields(tester);
      await tester.ensureVisible(find.text('Set new password'));
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('connection reset'), findsNothing);
    });

    testWidgets('Cancel calls the injected cancel callback, not '
        'completePasswordRecovery', (tester) async {
      var cancelCalls = 0;
      var completeCalls = 0;
      await tester.pumpWidget(
        _wrap(
          ResetPasswordScreen(
            completePasswordRecovery: (newPassword) async => completeCalls++,
            cancel: () async => cancelCalls++,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelCalls, 1);
      expect(completeCalls, 0);
    });
  });
}
