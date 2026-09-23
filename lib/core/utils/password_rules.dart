/// The same minimum-length rule SignupScreen has always used for account
/// creation, pulled out into one place so ChangePasswordScreen's "new
/// password" field can enforce it too without the two copies drifting
/// apart — the whole point of asking someone to change their password is
/// defeated if they can change it to something weaker than sign-up allows.
class PasswordRules {
  PasswordRules._();

  static const int minLength = 6;

  /// Returns a user-facing error message, or null if [value] satisfies
  /// the rule.
  static String? validate(String? value) =>
      (value == null || value.length < minLength)
      ? 'Minimum $minLength characters'
      : null;
}
