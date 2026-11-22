// Signing in with Apple and with an email code (2026-11-22): the login
// screen's new options, the code screen's two steps, the profile setup
// for accounts made that way, and AuthGate showing it before the app.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/features/auth/auth_gate.dart';
import 'package:michelin_passport/features/auth/email_code_screen.dart';
import 'package:michelin_passport/features/auth/login_screen.dart';
import 'package:michelin_passport/features/auth/profile_setup_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

/// A field holding [text] (the Name field's hint is also "Jane Doe").
Finder _typed(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

Session _session() => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {'apple_name': 'Jane Doe'},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

void main() {
  group('LoginScreen', () {
    testWidgets('offers Apple only where asked, and email always', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('Or sign in with your password'), findsOneWidget);

      await tester.pumpWidget(_wrap(const LoginScreen(showApple: true)));
      await tester.pump();
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('a cancelled Apple sheet shows no error', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          LoginScreen(
            showApple: true,
            signInWithApple: () async {
              calls++;
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      expect(calls, 1);
      expect(find.textContaining("didn't work"), findsNothing);
    });

    testWidgets('a failed Apple sign-in says so', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LoginScreen(
            showApple: true,
            signInWithApple: () async => throw Exception('apple'),
          ),
        ),
      );
      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      expect(
        find.text("Signing in with Apple didn't work. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets('Continue with email opens the code screen', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailCodeScreen), findsOneWidget);
    });
  });

  group('EmailCodeScreen', () {
    testWidgets('sends a code, then verifies the six digits', (tester) async {
      final sent = <String>[];
      final verified = <String>[];
      await tester.pumpWidget(
        _wrap(
          EmailCodeScreen(
            sendCode: (email) async => sent.add(email),
            verifyCode: ({required email, required code}) async =>
                verified.add('$email:$code'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'jane@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(sent, ['jane@example.com']);
      expect(
        find.text('We sent a six digit code to jane@example.com.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(verified, isEmpty);
      expect(
        find.text('Enter the six digit code from the email.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(verified, ['jane@example.com:123456']);
    });

    testWidgets('a wrong code says so and can be sent again', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _wrap(
          EmailCodeScreen(
            sendCode: (email) async => sent.add(email),
            verifyCode: ({required email, required code}) async =>
                throw const AuthException('Token has expired or is invalid'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'jane@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.textContaining("That code didn't work"), findsOneWidget);

      await tester.ensureVisible(find.text('Send a new code'));
      await tester.tap(find.text('Send a new code'));
      await tester.pump();
      expect(sent, ['jane@example.com', 'jane@example.com']);
      expect(find.text('A new code is on its way.'), findsOneWidget);
    });

    testWidgets('an address without @ is not sent', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _wrap(EmailCodeScreen(sendCode: (email) async => sent.add(email))),
      );
      await tester.enterText(find.byType(TextFormField), 'jane');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(sent, isEmpty);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });

  group('ProfileSetupScreen', () {
    testWidgets('offers Apple\'s name and saves name and username', (
      tester,
    ) async {
      final saved = <String>[];
      var done = false;
      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            userId: 'user-1',
            suggestedName: 'Jane Doe',
            onSaved: () => done = true,
            save:
                ({
                  required displayName,
                  required username,
                  homeCountryCode,
                }) async => saved.add('$displayName|$username'),
          ),
        ),
      );
      expect(_typed('Jane Doe'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'Jane.Doe');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(saved, ['Jane Doe|jane.doe']);
      expect(done, isTrue);
    });

    testWidgets('a taken username keeps the screen with the message', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            userId: 'user-1',
            onSaved: () => done = true,
            save:
                ({
                  required displayName,
                  required username,
                  homeCountryCode,
                }) async => throw const AuthException(
                  'That username is already taken.',
                ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Jane');
      await tester.enterText(find.byType(TextFormField).at(1), 'jane');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('That username is already taken.'), findsOneWidget);
      expect(done, isFalse);
    });
  });

  group('AuthGate', () {
    testWidgets('an account without a username gets the setup first', (
      tester,
    ) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            needsTwoStep: (_) => false,
            needsProfileSetup: (_) async => true,
            hasSeenWelcome: (_) async => true,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(AuthState(AuthChangeEvent.signedIn, _session()));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      expect(_typed('Jane Doe'), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('an account with a username goes straight on', (tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            needsTwoStep: (_) => false,
            needsProfileSetup: (_) async => false,
            hasSeenWelcome: (_) async => true,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(AuthState(AuthChangeEvent.signedIn, _session()));
      await tester.pumpAndSettle();
      expect(find.text('App'), findsOneWidget);
    });
  });
}
