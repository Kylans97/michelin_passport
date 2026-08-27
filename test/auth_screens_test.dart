// Covers LoginScreen/SignupScreen's redesigned presentation (Step 4A).
//
// Both screens are safe to pump directly here — unlike most other screens
// in this app, neither touches Supabase.instance eagerly: _auth is a
// `late final` field only read inside _submit(), and _submit() itself
// checks Form validation BEFORE ever reading _auth (see each screen's own
// _submit). So a tap on "Sign in"/"Create account" with invalid/empty
// fields exercises the real validation path with no Supabase session
// needed — it returns before the Supabase-backed call. Only a tap that
// would pass validation (a real sign-in/sign-up attempt) requires a live
// session, so that path is intentionally not exercised here — same
// limitation this project's other tests document for screens that
// construct Supabase-backed repositories.
//
// For the same reason, SignupScreen's post-submit "check your inbox"
// success state (_success, only reachable after a real signUp() call)
// isn't exercised here either.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart'
    show csMonogramAssetPath;
import 'package:michelin_passport/features/auth/login_screen.dart';
import 'package:michelin_passport/features/auth/signup_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('LoginScreen', () {
    testWidgets('renders the Chasing Stars brand treatment on a deep-green '
        'canvas', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.deepGreen);
      expect(find.text('MANTELIER'), findsOneWidget);
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (picture.bytesLoader as SvgAssetLoader).assetName,
        csMonogramAssetPath,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Email and Password field labels', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('renders the "Sign in" primary CTA', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('renders the secondary "Create an account" navigation link '
        'and navigates to SignupScreen', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.text('New to Mantelier?'), findsOneWidget);
      expect(find.text('Create an account →'), findsOneWidget);
      await tester.tap(find.text('Create an account →'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('shows no "Forgot password?" link (no backend for it '
        'exists)', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.textContaining('Forgot password'), findsNothing);
    });

    testWidgets('password field has a visibility toggle and starts hidden', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('submitting empty fields shows validation errors without '
        'touching Supabase', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no Playfair Display remains anywhere on the screen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(
          text.style?.fontFamily ?? '',
          isNot(contains('PlayfairDisplay')),
        );
      }
    });

    testWidgets('renders at 320px and 390px with no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(const LoginScreen()));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders at 1.6x text scale with no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const LoginScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('remains usable with the keyboard open (reduced viewport '
        'height) — no overflow, CTA still present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewInsets: EdgeInsets.only(bottom: 336), // typical iOS keyboard
            ),
            child: const LoginScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('SignupScreen', () {
    testWidgets('renders the Chasing Stars brand treatment, compact', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.text('MANTELIER'), findsOneWidget);
      expect(find.text('Create your account.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Name, Email and Password field labels', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('renders the "Create account" primary CTA', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('renders the secondary "Sign in" link and a back '
        'affordance', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.text('Already a member?'), findsOneWidget);
      expect(find.text('Sign in →'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('password field has a visibility toggle', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('submitting empty fields shows validation errors without '
        'touching Supabase', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      // The Username field (Social Foundation Step 1) added enough height
      // that "Create account" can sit below the default 800x600 test
      // surface's fold — scroll it into view rather than tapping blind.
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      // Two matches, correctly: the password field's own hintText is the
      // same copy ('Minimum 6 characters') as its validation error —
      // unchanged from the original signup_screen.dart, not something
      // this redesign introduced or should silently rewrite.
      expect(find.text('Minimum 6 characters'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no Playfair Display remains anywhere on the screen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(
          text.style?.fontFamily ?? '',
          isNot(contains('PlayfairDisplay')),
        );
      }
    });

    testWidgets('renders at 320px and 390px with no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(const SignupScreen()));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders at 1.6x text scale with no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const SignupScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('remains usable with the keyboard open — no overflow, CTA '
        'still present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              viewInsets: EdgeInsets.only(bottom: 336),
            ),
            child: const SignupScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('short iPhone-like height (320x568) with no overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
