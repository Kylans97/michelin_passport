// Covers the sign-up confirmation fix: production's Site URL was still
// Supabase's default http://localhost:3000 and signUp() passed no
// emailRedirectTo, so a confirmed account ended on "cannot connect to the
// server". Four layers, each against the real code path where possible:
//
// - AuthRepository puts the right redirect_to on the wire (a real
//   SupabaseClient over a MockClient — the request GoTrue actually gets).
// - authLinkNoticeFor() is fed the exact exceptions gotrue itself raises
//   for an expired/used link and a missing PKCE verifier — produced by a
//   real GoTrueClient.getSessionFromUrl(), not hand-built lookalikes, so a
//   gotrue upgrade that remaps error_code would fail here.
// - AuthGate turns those stream errors into a LoginScreen notice, and
//   ignores errors that have nothing to do with a link.
// - LoginScreen offers a new confirmation link on email_not_confirmed.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/auth_repository.dart';
import 'package:michelin_passport/features/auth/auth_gate.dart';
import 'package:michelin_passport/features/auth/auth_link_notice.dart';
import 'package:michelin_passport/features/auth/login_screen.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _items[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

Future<Object> _errorFrom(GoTrueClient client, String url) async {
  try {
    await client.getSessionFromUrl(Uri.parse(url));
  } catch (e) {
    return e;
  }
  fail('getSessionFromUrl($url) unexpectedly succeeded');
}

void main() {
  group('AuthRepository confirmation redirects', () {
    late List<http.Request> requests;
    late AuthRepository repo;

    setUp(() {
      requests = [];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'id': 'user-1',
              'aud': 'authenticated',
              'email': 'new@example.com',
              'created_at': '2026-10-30T00:00:00Z',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      repo = AuthRepository(client);
    });

    test('signUp sends the confirmation link to /auth/confirm, never the '
        'Site URL fallback', () async {
      await repo.signUp(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'New Member',
        username: 'new.member',
      );
      final signup = requests.singleWhere(
        (r) => r.url.path.endsWith('/signup'),
      );
      expect(
        signup.url.queryParameters['redirect_to'],
        'https://mantelier.app/auth/confirm',
      );
    });

    test(
      'a resent confirmation goes to the web-only /auth/confirmed',
      () async {
        await repo.resendSignupConfirmation('new@example.com');
        final resend = requests.singleWhere(
          (r) => r.url.path.endsWith('/resend'),
        );
        expect(
          resend.url.queryParameters['redirect_to'],
          'https://mantelier.app/auth/confirmed',
        );
        expect(jsonDecode(resend.body)['type'], 'signup');
      },
    );
  });

  group('authLinkNoticeFor', () {
    final client = GoTrueClient(
      url: 'https://example.supabase.co/auth/v1',
      asyncStorage: _MemoryStorage(),
      flowType: AuthFlowType.pkce,
    );

    test(
      "GoTrue's own expired/used-link redirect maps to expiredOrUsed",
      () async {
        // The exact fragment production's /verify returned for a bad token
        // on 2026-10-30.
        final error = await _errorFrom(
          client,
          'https://mantelier.app/auth/confirm#error=access_denied'
          '&error_code=otp_expired'
          '&error_description=Email+link+is+invalid+or+has+expired&sb=',
        );
        expect(authLinkNoticeFor(error), AuthLinkNotice.expiredOrUsed);
      },
    );

    test('a code with no stored PKCE verifier (reinstall, other device) maps '
        'to verifiedSignInNeeded', () async {
      final error = await _errorFrom(
        client,
        'https://mantelier.app/auth/confirm?code=abc',
      );
      expect(authLinkNoticeFor(error), AuthLinkNotice.verifiedSignInNeeded);
    });

    test('flow-state errors from the code exchange map to '
        'verifiedSignInNeeded', () {
      expect(
        authLinkNoticeFor(
          AuthApiException(
            'invalid flow state',
            code: 'flow_state_not_found',
          ),
        ),
        AuthLinkNotice.verifiedSignInNeeded,
      );
    });

    test('errors unrelated to a link produce no notice', () {
      expect(
        authLinkNoticeFor(const AuthException('Session expired.')),
        isNull,
      );
      expect(authLinkNoticeFor(StateError('boom')), isNull);
    });
  });

  group('AuthGate link notices', () {
    Future<StreamController<AuthState>> pumpGate(WidgetTester tester) async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: controller.stream,
            hasSeenWelcome: (_) async => true,
            child: const Text('App'),
          ),
        ),
      );
      controller.add(const AuthState(AuthChangeEvent.initialSession, null));
      await tester.pump();
      return controller;
    }

    testWidgets('an expired-link error shows its notice on LoginScreen', (
      tester,
    ) async {
      final controller = await pumpGate(tester);
      controller.addError(
        const AuthException(
          'Email link is invalid or has expired',
          statusCode: 'otp_expired',
          code: 'access_denied',
        ),
      );
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(AuthLinkNotice.expiredOrUsed.message), findsOneWidget);
    });

    testWidgets('a non-link error leaves LoginScreen without a notice', (
      tester,
    ) async {
      final controller = await pumpGate(tester);
      controller.addError(const AuthException('Session expired.'));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      for (final notice in AuthLinkNotice.values) {
        expect(find.text(notice.message), findsNothing);
      }
    });

    testWidgets('a later session clears the notice', (tester) async {
      final controller = await pumpGate(tester);
      controller.addError(
        const AuthException(
          'Code verifier could not be found in local storage.',
        ),
      );
      await tester.pump();
      expect(
        find.text(AuthLinkNotice.verifiedSignInNeeded.message),
        findsOneWidget,
      );
      controller.add(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'token',
            tokenType: 'bearer',
            user: const User(
              id: 'user-1',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('App'), findsOneWidget);
      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text(AuthLinkNotice.verifiedSignInNeeded.message),
        findsNothing,
      );
    });
  });

  group('LoginScreen unconfirmed email', () {
    testWidgets('email_not_confirmed offers a new link and sends it to the '
        'typed address', (tester) async {
      final resentTo = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            signIn: ({required email, required password}) async =>
                throw AuthApiException(
                  'Email not confirmed',
                  statusCode: '400',
                  code: 'email_not_confirmed',
                ),
            resendConfirmation: (email) async => resentTo.add(email),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.textContaining("isn't confirmed yet"), findsOneWidget);
      await tester.tap(find.text('Send a new confirmation link'));
      await tester.pump();

      expect(resentTo, ['new@example.com']);
      expect(
        find.textContaining('A new confirmation link is on its way'),
        findsOneWidget,
      );
      expect(find.text('Send a new confirmation link'), findsNothing);
    });

    testWidgets('any other sign-in error offers no resend', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            signIn: ({required email, required password}) async =>
                throw AuthApiException(
                  'Invalid login credentials',
                  statusCode: '400',
                  code: 'invalid_credentials',
                ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(find.text('Send a new confirmation link'), findsNothing);
    });
  });
}
