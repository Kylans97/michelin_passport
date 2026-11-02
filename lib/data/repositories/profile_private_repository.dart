import 'package:supabase_flutter/supabase_flutter.dart';

/// What a member keeps to themself (profile_private, 20261101210000):
/// their birth date and whether Mantelier greets them on it.
class ProfilePrivate {
  final DateTime? birthDate;
  final bool birthdayGreeting;

  const ProfilePrivate({this.birthDate, this.birthdayGreeting = true});
}

/// The youngest birth date a member may give: 16 years ago today, as the
/// terms require (the database refuses a later one).
DateTime latestAllowedBirthDate([DateTime? today]) {
  final t = today ?? DateTime.now();
  return DateTime(t.year - 16, t.month, t.day);
}

/// "14 March 1990".
String formatBirthDate(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Reads and writes the signed-in member's own row. RLS lets nobody else
/// see it, friends included; admins see only grouped counts
/// (admin_get_member_insights).
class ProfilePrivateRepository {
  ProfilePrivateRepository(this._client);

  final SupabaseClient _client;

  Future<ProfilePrivate> load(String userId) async {
    final row = await _client
        .from('profile_private')
        .select('birth_date, birthday_greeting')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const ProfilePrivate();
    return ProfilePrivate(
      birthDate: row['birth_date'] == null
          ? null
          : DateTime.parse(row['birth_date'] as String),
      birthdayGreeting: (row['birthday_greeting'] as bool?) ?? true,
    );
  }

  Future<void> save(String userId, ProfilePrivate value) {
    final d = value.birthDate;
    return _client.from('profile_private').upsert({
      'user_id': userId,
      'birth_date': d == null
          ? null
          : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'birthday_greeting': value.birthdayGreeting,
    });
  }
}
