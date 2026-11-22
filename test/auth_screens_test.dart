// Covers the entrance (LoginScreen) and the password sign-in behind it
// (PasswordSignInScreen), as redesigned by the sign-up flow of 2026-11-22.
//
// Both are safe to pump directly: neither touches Supabase.instance
// eagerly (_auth is a `late final` read only inside a submit, and the
// password form validates BEFORE reading it), so empty-field validation
// runs with no session. A real sign-in is not exercised here.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/auth/email_code_screen.dart';
import 'package:michelin_passport/features/auth/forgot_password_screen.dart';
import 'package:michelin_passport/features/auth/login_screen.dart';
import 'package:michelin_passport/features/auth/password_sign_in_screen.dart';
import 'package:michelin_passport/features/auth/widgets/auth_presentation.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('LoginScreen, the entrance', () {
    testWidgets('the official lockup on deep green', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.deepGreen);
      final assets = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((p) => (p.bytesLoader as SvgAssetLoader).assetName)
          .toList();
      expect(assets, [csWordmarkAssetPath]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one way in: no password form and no separate sign-up', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('I have a password'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Create an account →'), findsNothing);
      expect(
        find.textContaining('New or returning, it is the same step.'),
        findsOneWidget,
      );
    });

    testWidgets('Continue with email opens the code screen', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailCodeScreen), findsOneWidget);
    });

    testWidgets('I have a password opens the password sign-in', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen(showApple: false)));
      await tester.ensureVisible(find.text('I have a password'));
      await tester.tap(find.text('I have a password'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordSignInScreen), findsOneWidget);
    });

    testWidgets('a notice from an emailed link shows above the brand', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LoginScreen(showApple: false, notice: 'Link used.')),
      );
      expect(find.text('Link used.'), findsOneWidget);
    });

    testWidgets('no overflow at 320 and 390 wide, or a short phone', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 844),
        Size(390, 844),
        Size(320, 568),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(_wrap(const LoginScreen(showApple: true)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('no overflow at 1.6x text scale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: LoginScreen(showApple: true),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('PasswordSignInScreen', () {
    testWidgets('email, password and the Sign in button', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordSignInScreen()));
      expect(find.text('Sign in with your password'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Forgot password? opens ForgotPasswordScreen', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordSignInScreen()));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('the password starts hidden and can be shown', (tester) async {
      await tester.pumpWidget(_wrap(const PasswordSignInScreen()));
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('empty fields show validation without touching Supabase', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PasswordSignInScreen()));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Minimum 6 characters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('usable with the keyboard open', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              viewInsets: EdgeInsets.only(bottom: 336),
            ),
            child: PasswordSignInScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
