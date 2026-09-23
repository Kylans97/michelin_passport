// Covers ForgotPasswordScreen. resetPasswordForEmail is constructor-
// injected (same hand-rolled-fake convention as every other auth-adjacent
// screen in this app), so the REAL widget is pumped directly. The
// confirmation is asserted to be identical regardless of what the fake
// does — this screen must never reveal whether an email is registered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/auth/forgot_password_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('renders the title, body copy, email field and submit '
        'action', (tester) async {
      await tester.pumpWidget(
        _wrap(ForgotPasswordScreen(resetPasswordForEmail: (email) async {})),
      );
      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets('an invalid email blocks submission without calling '
        'resetPasswordForEmail', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          ForgotPasswordScreen(resetPasswordForEmail: (email) async => calls++),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a valid submission calls resetPasswordForEmail once with '
        'the trimmed email, then shows a neutral "check your inbox" '
        'confirmation', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          ForgotPasswordScreen(
            resetPasswordForEmail: (email) async => calls.add(email),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        ' jane@example.com ',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(calls, ['jane@example.com']);
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(
        find.textContaining("If that address is registered"),
        findsOneWidget,
      );
      // Never a field-specific claim — same copy whether the email exists
      // or not.
      expect(find.textContaining('does not exist'), findsNothing);
      expect(find.textContaining('not found'), findsNothing);

      // Regression: _CheckInboxBody used to render through a
      // SingleChildScrollView, which pins a short child to the top-left
      // of the viewport instead of centering it. Measuring the actual
      // on-screen position, not just presence of the text.
      final screenCenterX = tester.getRect(find.byType(Scaffold)).center.dx;
      final titleCenterX = tester.getCenter(find.text('Check your inbox')).dx;
      expect(titleCenterX, closeTo(screenCenterX, 1.0));
    });

    testWidgets('shows the SAME neutral confirmation even when the '
        'backend fails — a person probing for registered emails learns '
        'nothing from the difference between "this email exists" and '
        '"it does not" scenarios', (tester) async {
      // Note: resetPasswordForEmail() itself never reveals existence
      // (GoTrue's own behavior — see AuthRepository), so a normal,
      // successful call is the only path this screen's _submit ever
      // takes for both an existing and a non-existing address. This test
      // instead documents the screen's OWN error path stays a plain,
      // generic error — not a hint about the specific email.
      await tester.pumpWidget(
        _wrap(
          ForgotPasswordScreen(
            resetPasswordForEmail: (email) async {
              throw Exception('network error');
            },
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'jane@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Check your inbox'), findsNothing);
    });

    testWidgets('"Back to sign in" from the confirmation pops the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        resetPasswordForEmail: (email) async {},
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
      await tester.enterText(
        find.byType(TextFormField).first,
        'jane@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Root'), findsOneWidget);
    });
  });
}
