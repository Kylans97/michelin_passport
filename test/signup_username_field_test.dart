// Covers the Username field added to SignupScreen (Social Foundation
// Step 1). SignupScreen constructs AuthRepository/ProfileRepository
// against Supabase.instance.client eagerly (same established limitation
// as every other screen in this app that touches Supabase in initState/
// field initializers), so this only exercises client-side validation —
// the part that must never touch Supabase — mirroring
// auth_screens_test.dart's own existing "without touching Supabase" test
// for the pre-existing Name/Email/Password fields.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/auth/signup_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('SignupScreen username field', () {
    testWidgets('renders a Username label', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('submitting with an invalid username shows a validation error, '
        'without touching Supabase', (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      // Fill every OTHER field validly so only the username's own
      // validator can be responsible for blocking submission.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jane Doe'); // Name
      await tester.enterText(fields.at(1), 'ky'); // Username — too short
      await tester.enterText(fields.at(2), 'jane@example.com'); // Email
      await tester.enterText(fields.at(3), 'password123'); // Password

      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Usernames are 3–30 characters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(const SignupScreen()));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('username field tap target meets the accessible minimum', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      final size = tester.getSize(find.byType(TextFormField).at(1));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
