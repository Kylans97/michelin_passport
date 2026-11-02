// Covers two-step sign-in with an authenticator app: the helpers, reading
// from a session whether its code is still owed, AuthGate showing the code
// step, the code screen itself, and the settings — turning it on, a backup,
// and removing one with a code.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/two_step_repository.dart';
import 'package:michelin_passport/features/auth/auth_gate.dart';
import 'package:michelin_passport/features/auth/two_step_sign_in_screen.dart';
import 'package:michelin_passport/features/profile/two_step_settings_screen.dart';

GoTrueClient _dummyAuth() =>
    GoTrueClient(url: 'https://example.test/auth/v1', autoRefreshToken: false);

class _FakeTwoStepRepo extends TwoStepRepository {
  _FakeTwoStepRepo({List<TwoStepFactor>? factors})
    : _factors = factors ?? [],
      super(_dummyAuth());

  final List<TwoStepFactor> _factors;
  static const goodCode = '123456';
  final calls = <String>[];

  @override
  Future<List<TwoStepFactor>> factors() async => List.of(_factors);

  @override
  Future<TwoStepEnrollment> start() async {
    calls.add('start');
    return const TwoStepEnrollment(
      factorId: 'new-factor',
      uri: 'otpauth://totp/Mantelier:me@example.test?secret=ABCDEFGHIJKLMNOP',
      secret: 'ABCDEFGHIJKLMNOP',
    );
  }

  void _check(String code) {
    if (twoStepDigits(code) != goodCode) {
      throw const AuthException('Invalid TOTP code entered');
    }
  }

  @override
  Future<void> confirm(String factorId, String code) async {
    _check(code);
    calls.add('confirm:$factorId');
    _factors.add(TwoStepFactor(id: factorId, addedAt: DateTime(2026, 11, 2)));
  }

  @override
  Future<void> verifySignIn(String code) async {
    _check(code);
    calls.add('verify');
  }

  @override
  Future<void> remove(String factorId, String code) async {
    _check(code);
    calls.add('remove:$factorId');
    _factors.removeWhere((f) => f.id == factorId);
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
}

String _jwt(String aal) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'aal': aal, 'sub': 'user-1'})}.sig';
}

Session _session({required String aal, bool withFactor = true}) => Session(
  accessToken: _jwt(aal),
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    factors: withFactor
        ? [
            Factor(
              id: 'f1',
              friendlyName: 'Authenticator',
              factorType: FactorType.totp,
              status: FactorStatus.verified,
              createdAt: DateTime(2026, 11, 1),
              updatedAt: DateTime(2026, 11, 1),
            ),
          ]
        : null,
  ),
);

final _oneFactor = [
  TwoStepFactor(
    id: 'f1',
    name: 'Authenticator',
    addedAt: DateTime(2026, 11, 1),
  ),
];

void main() {
  group('helpers', () {
    test('a code keeps only its digits', () {
      expect(twoStepDigits(' 123 456 '), '123456');
      expect(twoStepDigits('12-34-56'), '123456');
    });

    test('the key reads in groups of four', () {
      expect(twoStepGroupedSecret('ABCDEFGHIJ'), 'ABCD EFGH IJ');
    });
  });

  group('sessionNeedsTwoStep', () {
    test('a password-only session with an authenticator owes a code', () {
      expect(sessionNeedsTwoStep(_session(aal: 'aal1')), isTrue);
    });

    test('after the code (aal2) nothing more is owed', () {
      expect(sessionNeedsTwoStep(_session(aal: 'aal2')), isFalse);
    });

    test('an account without two-step sign-in never owes one', () {
      expect(
        sessionNeedsTwoStep(_session(aal: 'aal1', withFactor: false)),
        isFalse,
      );
    });

    test('an unreadable token with an authenticator still owes a code', () {
      final s = _session(aal: 'aal1');
      final broken = Session(
        accessToken: 'not-a-jwt',
        tokenType: 'bearer',
        user: s.user,
      );
      expect(sessionNeedsTwoStep(broken), isTrue);
    });
  });

  group('AuthGate', () {
    Future<StreamController<AuthState>> pumpGate(
      WidgetTester tester, {
      required bool needsTwoStep,
      _FakeTwoStepRepo? repo,
    }) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            hasSeenWelcome: (_) async => true,
            markWelcomeSeen: (_) async {},
            needsTwoStep: (_) => needsTwoStep,
            twoStepRepository: repo ?? _FakeTwoStepRepo(),
            child: const Text('App'),
          ),
        ),
      );
      controller.add(
        AuthState(AuthChangeEvent.signedIn, _session(aal: 'aal1')),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('a session that owes its code shows the code step, not the '
        'app', (tester) async {
      await pumpGate(tester, needsTwoStep: true);
      expect(find.byType(TwoStepSignInScreen), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('a session that owes nothing goes straight to the app', (
      tester,
    ) async {
      await pumpGate(tester, needsTwoStep: false);
      expect(find.byType(TwoStepSignInScreen), findsNothing);
      expect(find.text('App'), findsOneWidget);
    });
  });

  group('TwoStepSignInScreen', () {
    Future<_FakeTwoStepRepo> pumpScreen(WidgetTester tester) async {
      final repo = _FakeTwoStepRepo();
      await tester.pumpWidget(
        MaterialApp(home: TwoStepSignInScreen(repository: repo)),
      );
      return repo;
    }

    testWidgets('a short code asks for six digits and sends nothing', (
      tester,
    ) async {
      final repo = await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the six-digit code.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a wrong code says so', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text("That code didn't match. Try the newest one."),
        findsOneWidget,
      );
    });

    testWidgets('the right code, spaces and all, verifies', (tester) async {
      final repo = await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), '123 456');
      await tester.tap(find.text('Continue'));
      // The screen keeps its spinner: AuthGate moves on once the
      // session is aal2, not this screen.
      await tester.pump();
      expect(repo.calls, ['verify']);
    });

    testWidgets('the sixth digit sends the code without a tap', (tester) async {
      final repo = await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump();
      expect(repo.calls, ['verify']);
    });

    testWidgets('the field keeps digits only, six at most', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), '00 3724 53x');
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '003724');
    });

    testWidgets('Sign out signs out', (tester) async {
      final repo = await pumpScreen(tester);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['signOut']);
    });
  });

  group('TwoStepSettingsScreen', () {
    testWidgets('off: Turn on, open the authenticator, confirm, and it is on', (
      tester,
    ) async {
      final repo = _FakeTwoStepRepo();
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TwoStepSettingsScreen(
            repository: repo,
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.text('ABCD EFGH IJKL MNOP'), findsOneWidget);

      await tester.tap(find.text('Open in authenticator app'));
      await tester.pumpAndSettle();
      expect(opened.single.scheme, 'otpauth');

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['start', 'confirm:new-factor']);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Two-step sign-in is on.'), findsOneWidget);
    });

    testWidgets('when no authenticator app opens, the key is offered instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TwoStepSetupScreen(
            repository: _FakeTwoStepRepo(),
            openLink: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in authenticator app'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No authenticator app opened. Copy the key below into one instead.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('on with one authenticator suggests a backup', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TwoStepSettingsScreen(
            repository: _FakeTwoStepRepo(factors: List.of(_oneFactor)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Authenticator'), findsOneWidget);
      expect(find.text('Added 1 Nov 2026'), findsOneWidget);
      expect(find.text('Add a backup authenticator'), findsOneWidget);
    });

    testWidgets('removing the last one needs a code, then it is off', (
      tester,
    ) async {
      final repo = _FakeTwoStepRepo(factors: List.of(_oneFactor));
      await tester.pumpWidget(
        MaterialApp(home: TwoStepSettingsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off two-step sign-in?'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '999999');
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(
        find.text("That code didn't match. Try the newest one."),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['remove:f1']);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Two-step sign-in is off.'), findsOneWidget);
    });
  });
}
