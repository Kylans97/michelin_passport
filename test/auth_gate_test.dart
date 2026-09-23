// Covers AuthGate's sticky password-recovery state — the whole reason it's
// a StatefulWidget with its own subscription rather than a StreamBuilder
// keyed on "the latest AuthState" (see its own doc comment). A recovery
// link leaves a real session behind that Supabase auto-refreshes while the
// app is open; a naive "latest event" read would treat that later
// tokenRefreshed event as "back to normal" and drop the person into the
// main app before they've set a new password. [authStateChanges] is
// injected here as a plain StreamController so this can be driven directly,
// without reaching into gotrue's own @internal notifyAllSubscribers.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/features/auth/auth_gate.dart';
import 'package:michelin_passport/features/auth/login_screen.dart';
import 'package:michelin_passport/features/auth/reset_password_screen.dart';

User _fakeUser() => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

Session _fakeSession() =>
    Session(accessToken: 'token', tokenType: 'bearer', user: _fakeUser());

void main() {
  group('AuthGate', () {
    testWidgets('shows the branded splash before the first auth event', (
      tester,
    ) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            child: const Text('App'),
          ),
        ),
      );
      // Not pumpAndSettle — the splash's own CircularProgressIndicator
      // animates forever, so "settled" never arrives while it's showing.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('a null session shows LoginScreen', (tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(const AuthState(AuthChangeEvent.initialSession, null));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('a signedIn session for an account that has already seen '
        'the welcome flow shows the app', (tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            // Passed straight through to OnboardingGate (see AuthGate's
            // own doc comment on these two params) so this never falls
            // back to a real ProfileRepository/Supabase.instance call.
            hasSeenWelcome: (userId) async => true,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(
        AuthState(AuthChangeEvent.signedIn, _fakeSession()),
      );
      // Two pumps, not pumpAndSettle: OnboardingGate shows BrandedSplash
      // (its own infinitely-animating spinner, same as AuthGate's own)
      // for the one microtask its hasSeenWelcome check takes — settle
      // would never terminate while that's on screen. One pump lands on
      // the splash; the second lets the check's Future resolve.
      await tester.pump();
      await tester.pump();
      expect(find.text('App'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('passwordRecovery with a session shows ResetPasswordScreen, '
        'not the app', (tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(
        AuthState(AuthChangeEvent.passwordRecovery, _fakeSession()),
      );
      await tester.pump();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('a later tokenRefreshed event does NOT clear recovery mode '
        '— the exact regression this StatefulWidget exists to prevent', (
      tester,
    ) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            child: const Text('App'),
          ),
        ),
      );
      final session = _fakeSession();
      controller.add(AuthState(AuthChangeEvent.passwordRecovery, session));
      await tester.pump();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // Supabase's own auto-refresh, unrelated to the recovery flow itself.
      controller.add(AuthState(AuthChangeEvent.tokenRefreshed, session));
      await tester.pump();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('signedOut after a recovery clears the pending flag and '
        'returns to LoginScreen', (tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(
        AuthState(AuthChangeEvent.passwordRecovery, _fakeSession()),
      );
      await tester.pump();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // completePasswordRecovery()'s own explicit signOut() — see
      // AuthRepository — is what actually fires this in production.
      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });

    testWidgets(
      'if the recovery flag is somehow set with no session, falls back to '
      'LoginScreen rather than crashing',
      (tester) async {
        final controller = StreamController<AuthState>.broadcast();
        addTearDown(controller.close);
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              authStateChanges: controller.stream,
              child: const Text('App'),
            ),
          ),
        );
        controller.add(
          const AuthState(AuthChangeEvent.passwordRecovery, null),
        );
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
