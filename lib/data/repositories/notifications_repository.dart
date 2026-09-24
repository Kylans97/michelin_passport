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

  Future<List<AppNotification>> getNotifications() async {
    final rows = await _client.rpc('get_notifications');
    return (rows as List)
        .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final result = await _client.rpc('get_unread_notification_count');
    return result as int;
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
