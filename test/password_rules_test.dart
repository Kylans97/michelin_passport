// PasswordRules is the single source of truth for "how weak is too weak",
// shared by SignupScreen's password field and ChangePasswordScreen's new-
// password field — the whole point of the extraction (see the class's own
// doc comment) is that a password rejected at sign-up can never be
// accepted when changing password later, so this is tested once here
// rather than duplicated per screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/password_rules.dart';

void main() {
  group('PasswordRules.validate', () {
    test('rejects a password shorter than 6 characters', () {
      expect(PasswordRules.validate('abc12'), 'Minimum 6 characters');
    });

    test('accepts a password exactly 6 characters long', () {
      expect(PasswordRules.validate('abc123'), isNull);
    });

    test('accepts a longer password', () {
      expect(PasswordRules.validate('a much longer passphrase'), isNull);
    });

    test('rejects null', () {
      expect(PasswordRules.validate(null), 'Minimum 6 characters');
    });

    test('rejects an empty string', () {
      expect(PasswordRules.validate(''), 'Minimum 6 characters');
    });
  });
}
