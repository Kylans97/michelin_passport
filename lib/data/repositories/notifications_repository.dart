import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_notification.dart';

/// Reads go through `get_notifications()`/`get_unread_notification_count()`
/// (security definer — see their own comments in the migration for why a
/// plain client-side select/join can't resolve a friend-request
/// notification's other participant). Marking read is a plain table
/// update: `notifications_update` RLS already scopes it to the caller's
/// own rows, so no RPC is needed for that half, matching how
/// `updateAvatarPath` etc. write directly rather than through an RPC.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  /// Reads the newest functions this server has: _v3 (20261021120000,
  /// adds trip invitations), else _v2 (20261018130000, adds event
  /// notifications), else the originals — each step down on PostgREST's
  /// "function not found" (PGRST202), so this build works on any side of
  /// those migrations. A row of a type this build doesn't know is skipped,
  /// never a reason to fail the whole list.
  Future<List<AppNotification>> getNotifications() async {
    final rows = await _rpcWithFallback(const [
      'get_notifications_v3',
      'get_notifications_v2',
      'get_notifications',
    ]);
    return [
      for (final r in rows as List) ?AppNotification.tryFromRow(r as Map<String, dynamic>),
    ];
  }

  Future<int> getUnreadCount() async {
    final result = await _rpcWithFallback(const [
      'get_unread_notification_count_v3',
      'get_unread_notification_count_v2',
      'get_unread_notification_count',
    ]);
    return result as int;
  }

  Future<dynamic> _rpcWithFallback(List<String> names) async {
    for (final name in names.take(names.length - 1)) {
      try {
        return await _client.rpc(name);
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST202') rethrow;
      }
    }
    return _client.rpc(names.last);
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // No .eq('recipient_id', ...) needed — notifications_update RLS already
  // restricts this to the caller's own rows regardless of what filter is
  // passed here.
  Future<void> markAllAsRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
  }
}
