// Covers UserProfile.fromSupabase's home_country_code mapping — the
// column already existed, unused, before this change; this is the first
// place anything in the app reads it. Internal-only field (never shown to
// other users — see the model's own doc comment), so this pure-function
// test is the only coverage available: ProfileRepository has no DI seam
// (same established limitation as every other Supabase-eager repository
// in this app), and the Edit Profile sheet that reads it back is a
// private class, unreachable from a test file in a different library.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/user_profile.dart';

Map<String, dynamic> _row({String? homeCountryCode}) => {
  'id': 'user-1',
  'username': 'kylan',
  'display_name': 'Kylan',
  'created_at': '2026-01-01T00:00:00Z',
  'home_country_code': homeCountryCode,
};

void main() {
  group('UserProfile.fromSupabase — home_country_code', () {
    test('maps a present code', () {
      final profile = UserProfile.fromSupabase(
        profileRow: _row(homeCountryCode: 'NL'),
        visited: const [],
        email: 'kylan@example.com',
      );
      expect(profile.homeCountryCode, 'NL');
    });

    test('is null when the column is null — a normal, common value, not '
        'an error', () {
      final profile = UserProfile.fromSupabase(
        profileRow: _row(),
        visited: const [],
        email: 'kylan@example.com',
      );
      expect(profile.homeCountryCode, isNull);
    });
  });
}
