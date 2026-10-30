import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification_preferences.dart';

/// Device tokens and push preferences (20261030130000).
///
/// Tokens go through `register_push_device` / `unregister_push_device`
/// only — a token moving to the account now signed in on the device is a
/// write RLS can't express. Preferences are a plain owner-only table: no
/// row means the defaults, and the first change creates it.
class PushRepository {
  PushRepository(this._client);

  final SupabaseClient _client;

  Future<void> registerDevice({
    required String token,
    required String apnsEnvironment,
    String? appVersion,
  }) => _client.rpc(
    'register_push_device',
    params: {
      'p_token': token,
      'p_apns_environment': apnsEnvironment,
      'p_app_version': appVersion,
    },
  );

  Future<void> unregisterDevice(String token) =>
      _client.rpc('unregister_push_device', params: {'p_token': token});

  Future<NotificationPreferences> getPreferences(String userId) async {
    final row = await _client
        .from('notification_preferences')
        .select('push_friend_requests, push_followed_venue_events')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromRow(row);
  }

  /// Writes the whole row, so the first change also records the other
  /// toggle's current (default) value rather than leaving it implicit.
  Future<void> savePreferences(String userId, NotificationPreferences prefs) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      ...prefs.toRow(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
