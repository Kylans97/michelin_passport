// Ways to sign in (2026-11-22): the email row, Apple linked or not, and
// linking Apple to the signed-in account.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/features/profile/sign_in_methods_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the email and an unlinked Apple with the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SignInMethodsScreen(
          email: 'elise@example.com',
          showApple: true,
          hasAppleLinked: () async => false,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ways to sign in'), findsOneWidget);
    expect(
      find.text('elise@example.com\nA six digit code sent here always works.'),
      findsOneWidget,
    );
    expect(find.textContaining('Not linked.'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('linking turns the row to Linked and hides the button', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        SignInMethodsScreen(
          email: 'elise@example.com',
          showApple: true,
          hasAppleLinked: () async => false,
          linkApple: () async {
            calls++;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(calls, 1);
    expect(
      find.textContaining('Linked. You can now sign in with Apple'),
      findsOneWidget,
    );
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('a cancelled sheet changes nothing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SignInMethodsScreen(
          email: 'elise@example.com',
          showApple: true,
          hasAppleLinked: () async => false,
          linkApple: () async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(find.textContaining('Not linked.'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('an Apple ID on another account says so', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SignInMethodsScreen(
          email: 'elise@example.com',
          showApple: true,
          hasAppleLinked: () async => false,
          linkApple: () async => throw const AuthException(
            'This Apple ID already belongs to another Mantelier account.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();
    expect(
      find.text('This Apple ID already belongs to another Mantelier account.'),
      findsOneWidget,
    );
  });

  testWidgets('already linked: no button', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SignInMethodsScreen(
          email: 'elise@example.com',
          showApple: true,
          hasAppleLinked: () async => true,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Linked. Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
  });
}
