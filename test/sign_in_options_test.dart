// The sign-up flow of 2026-11-22: the entrance's two ways in, the code
// screen's six boxes, the three questions with the Passport filling in,
// the Passport issued, and AuthGate showing the setup before the app.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/core/utils/username_rules.dart';
import 'package:michelin_passport/features/auth/auth_gate.dart';
import 'package:michelin_passport/features/auth/email_code_screen.dart';
import 'package:michelin_passport/features/auth/login_screen.dart';
import 'package:michelin_passport/features/auth/password_sign_in_screen.dart';
import 'package:michelin_passport/features/auth/profile_setup_screen.dart';
import 'package:michelin_passport/models/venue_country.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

/// A field holding [text].
Finder _typed(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

Session _session() => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {'apple_name': 'Elise Laurent'},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

const _countries = [
  VenueCountry(name: 'Belgium', code: 'BE', flag: ''),
  VenueCountry(name: 'France', code: 'FR', flag: ''),
  VenueCountry(name: 'Germany', code: 'DE', flag: ''),
  VenueCountry(name: 'Italy', code: 'IT', flag: ''),
  VenueCountry(name: 'Luxembourg', code: 'LU', flag: ''),
  VenueCountry(name: 'Netherlands', code: 'NL', flag: ''),
];

ProfileSetupScreen _setup({
  String? suggestedName = 'Elise Laurent',
  Set<String> taken = const {},
  List<String>? saved,
  VoidCallback? onSaved,
  Future<void> Function()? failSave,
}) => ProfileSetupScreen(
  userId: 'user-1',
  suggestedName: suggestedName,
  onSaved: onSaved ?? () {},
  deviceCountryCode: 'NL',
  today: DateTime(2026, 11, 22),
  loadCountries: () async => _countries,
  isUsernameAvailable: (u) async => !taken.contains(u),
  loadMemberNumber: () async => 31,
  save: ({required displayName, required username, homeCountryCode}) async {
    if (failSave != null) await failSave();
    saved?.add('$displayName|$username|$homeCountryCode');
  },
);

void main() {
  group('LoginScreen', () {
    testWidgets('offers Apple only where asked, and email always', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with email'), findsOneWidget);

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
  });

  group('EmailCodeScreen', () {
    testWidgets('sends a code, and the sixth digit verifies it', (
      tester,
    ) async {
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
      expect(find.text('Your email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'elise@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(sent, ['elise@example.com']);
      expect(find.text('Check your mail'), findsOneWidget);
      expect(
        find.text('A six digit code is on its way to elise@example.com.'),
        findsOneWidget,
      );
      expect(find.text('Send a new code in 1:00'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(verified, isEmpty);
      expect(find.text('5'), findsOneWidget); // drawn in its box

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(verified, ['elise@example.com:123456']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a wrong code says so, and a new one comes after a minute', (
      tester,
    ) async {
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
      await tester.enterText(find.byType(TextFormField), 'elise@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();
      expect(find.textContaining("That code didn't work"), findsOneWidget);

      expect(find.text('Send a new code'), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Send a new code'));
      await tester.pump();
      expect(sent, ['elise@example.com', 'elise@example.com']);
      expect(find.text('A new code is on its way.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Other address goes back to the email step', (tester) async {
      await tester.pumpWidget(
        _wrap(EmailCodeScreen(sendCode: (email) async {})),
      );
      await tester.enterText(find.byType(TextFormField), 'elise@example.com');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.tap(find.text('Other address'));
      await tester.pump();
      expect(find.text('Your email'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an address without @ is not sent', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        _wrap(EmailCodeScreen(sendCode: (email) async => sent.add(email))),
      );
      await tester.enterText(find.byType(TextFormField), 'elise');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(sent, isEmpty);
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('Use my password instead swaps to the password sign-in', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const EmailCodeScreen()));
      await tester.tap(find.text('Use my password instead'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordSignInScreen), findsOneWidget);
      expect(find.byType(EmailCodeScreen), findsNothing);
    });
  });

  group('UsernameRules.suggestionsFor', () {
    test('first.last, firstlast, first.l, flast', () {
      expect(UsernameRules.suggestionsFor('Elise Laurent'), [
        'elise.laurent',
        'eliselaurent',
        'elise.l',
        'elaurent',
      ]);
    });

    test('accents dropped and a family name of several words joined', () {
      expect(
        UsernameRules.suggestionsFor('Mathilde Van den Broeck').first,
        'mathilde.vandenbroeck',
      );
      expect(UsernameRules.suggestionsFor('Zoë').first, 'zoe');
      expect(UsernameRules.suggestionsFor('  '), isEmpty);
    });
  });

  group('ProfileSetupScreen', () {
    testWidgets('three questions, then the Passport issued', (tester) async {
      final saved = <String>[];
      var done = false;
      await tester.pumpWidget(
        _wrap(_setup(saved: saved, onSaved: () => done = true)),
      );
      await tester.pump();

      // 1: the name, Apple's offered, on the Passport already.
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(_typed('Elise Laurent'), findsOneWidget);
      expect(
        find.text('From your Apple Account. Change it if you like.'),
        findsOneWidget,
      );
      expect(find.text('not chosen yet'), findsNWidgets(2));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 2: a username made from it, checked, with free alternatives.
      expect(find.text('Pick a username'), findsOneWidget);
      expect(_typed('elise.laurent'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('eliselaurent'), findsOneWidget);
      expect(find.text('@elise.laurent'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 3: home, preselected from the device region.
      expect(find.text('Where is home?'), findsOneWidget);
      expect(find.text('From your iPhone settings'), findsOneWidget);
      await tester.tap(find.text('Belgium'));
      await tester.pump();
      await tester.tap(find.text('Issue my Passport'));
      await tester.pumpAndSettle();

      expect(saved, ['Elise Laurent|elise.laurent|BE']);
      expect(find.text('Your Passport is ready, Elise'), findsOneWidget);
      expect(find.text('NO. 31'), findsOneWidget);
      expect(find.text('22 XI 26'), findsOneWidget);
      expect(done, isFalse);
      await tester.tap(find.text('Show me around'));
      expect(done, isTrue);
    });

    testWidgets('a taken username is said, and an alternative is offered', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_setup(taken: {'elise.laurent'})));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('That username is already taken'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a username'), findsOneWidget);
      await tester.ensureVisible(find.text('eliselaurent'));
      await tester.tap(find.text('eliselaurent'));
      await tester.pump();
      expect(_typed('eliselaurent'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Where is home?'), findsOneWidget);
    });

    testWidgets('Skip saves without a home', (tester) async {
      final saved = <String>[];
      await tester.pumpWidget(_wrap(_setup(saved: saved)));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(saved, ['Elise Laurent|elise.laurent|null']);
      expect(find.text('Your Passport is ready, Elise'), findsOneWidget);
    });

    testWidgets('a refused save returns to the username with the reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _setup(
            failSave: () async =>
                throw const AuthException('That username is already taken.'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue my Passport'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a username'), findsOneWidget);
      expect(find.text('That username is already taken.'), findsOneWidget);
    });

    testWidgets('no name means no Continue past the first question', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_setup(suggestedName: null)));
      await tester.pump();
      expect(
        find.text('From your Apple Account. Change it if you like.'),
        findsNothing,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);
    });

    testWidgets('fits a short phone at a large text size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: _setup(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
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
      await tester.pump();
      await tester.pump();
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      expect(_typed('Elise Laurent'), findsOneWidget);
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
