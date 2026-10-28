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

  /// Reads the _v2 functions (20261018130000), which include event
  /// notifications. Falls back to the originals while a server doesn't
  /// have _v2 yet (PostgREST's "function not found", PGRST202), so this
  /// build works on either side of that migration. A row of a type this
  /// build doesn't know is skipped, never a reason to fail the whole list.
  Future<List<AppNotification>> getNotifications() async {
    final rows = await _rpcWithFallback('get_notifications_v2', 'get_notifications');
    return [
      for (final r in rows as List) ?AppNotification.tryFromRow(r as Map<String, dynamic>),
    ];
  }

  Future<int> getUnreadCount() async {
    final result = await _rpcWithFallback(
      'get_unread_notification_count_v2',
      'get_unread_notification_count',
    );
    return result as int;
  }

  Future<dynamic> _rpcWithFallback(String name, String fallback) async {
    try {
      return await _client.rpc(name);
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      return _client.rpc(fallback);
    }
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
