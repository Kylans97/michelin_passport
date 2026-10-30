import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_notification.dart';

/// Reads go through `get_notifications()`/`get_unread_notification_count()`
/// (security definer — see their own comments in the migration for why a
/// plain client-side select/join can't resolve a friend-request
/// notification's other participant). Marking read is a plain table
/// update: `notifications_update` RLS already scopes it to the caller's
/// own rows, so no RPC is needed for that half, matching how
/// `updateAvatarPath` etc. write directly rather than through an RPC.
/// Notifications per page. The table only ever grows; before paging, every
/// visit to Notifications downloaded a member's whole history (and, past
/// PostgREST's 1,000-row cap, silently lost the oldest).
const notificationsPageSize = 50;

/// One page of [NotificationsRepository.getNotifications].
class NotificationsPage {
  const NotificationsPage(this.notifications, {required this.hasMore});

  final List<AppNotification> notifications;

  /// Whether an older page may exist — judged on the rows the server sent,
  /// not on [notifications], which leaves out types this build can't show.
  final bool hasMore;
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  /// Reads the newest functions this server has: _v4 (20261030130000,
  /// adds followed venues' events), else _v3 (20261022120000,
  /// adds trip invitations), else _v2 (20261018130000, adds event
  /// notifications), else the originals — each step down on PostgREST's
  /// "function not found" (PGRST202), so this build works on any side of
  /// those migrations. A row of a type this build doesn't know is skipped,
  /// never a reason to fail the whole list.
  ///
  /// Paged newest first: PostgREST orders and ranges a set-returning
  /// function's result like a table, so this needs no server change and
  /// works against every version. `id` breaks created_at ties so a row
  /// never moves between pages. The unread badge reads its own count RPC,
  /// so it stays exact whatever has been paged in.
  Future<NotificationsPage> getNotifications({int offset = 0}) async {
    final rows = await _rpcWithFallback(
      const [
        'get_notifications_v4',
        'get_notifications_v3',
        'get_notifications_v2',
        'get_notifications',
      ],
      page: (rpc) => rpc
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + notificationsPageSize - 1),
    );
    final list = rows as List;
    return NotificationsPage([
      for (final r in list)
        ?AppNotification.tryFromRow(r as Map<String, dynamic>),
    ], hasMore: list.length == notificationsPageSize);
  }

  Future<int> getUnreadCount() async {
    final result = await _rpcWithFallback(const [
      'get_unread_notification_count_v4',
      'get_unread_notification_count_v3',
      'get_unread_notification_count_v2',
      'get_unread_notification_count',
    ]);
    return result as int;
  }

  Future<dynamic> _rpcWithFallback(
    List<String> names, {
    PostgrestTransformBuilder<dynamic> Function(
      PostgrestFilterBuilder<dynamic> rpc,
    )?
    page,
  }) async {
    Future<dynamic> call(String name) {
      final rpc = _client.rpc(name);
      return page == null ? rpc : page(rpc);
    }

    for (final name in names.take(names.length - 1)) {
      try {
        return await call(name);
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST202') rethrow;
      }
    }
    return call(names.last);
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
