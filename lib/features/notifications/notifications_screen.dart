import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../models/app_notification.dart';
import '../friends/friend_profile_screen.dart';
import '../friends/widgets/identity_row.dart';

/// Rebuilt to show real notifications (Notifications V1) — the previous
/// version of this screen was entirely a friend-request inbox wearing a
/// "Notifications" label; that functionality still exists here (a
/// [AppNotificationType.friendRequestReceived] row keeps its working
/// Accept/Decline, unchanged underneath — same [FriendshipRepository]
/// RPCs), it's just one of three types now instead of the whole screen.
///
/// Opening this screen marks everything unread AT LOAD TIME as read in
/// the background, but the fetched list itself keeps rendering with each
/// row's read state as it was AT FETCH TIME — otherwise the "here's what's
/// new" visual distinction this screen exists to show would disappear the
/// instant it appeared.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final _notificationsRepo = NotificationsRepository(
    Supabase.instance.client,
  );
  late final _friendRepo = FriendshipRepository(Supabase.instance.client);

  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _notificationsRepo.getNotifications().then((notifications) {
        // Fire-and-forget: the caller doesn't need to wait for this to
        // render the list, and a failure here shouldn't block viewing
        // notifications that already loaded successfully.
        _notificationsRepo.markAllAsRead().catchError((_) {});
        return notifications;
      });
    });
  }

  Future<void> _accept(AppNotification n) async {
    await _friendRepo.acceptRequest(n.subjectId);
    _load();
  }

  Future<void> _decline(AppNotification n) async {
    await _friendRepo.declineRequest(n.subjectId);
    _load();
  }

  void _openProfile(String userId) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FriendProfileScreen(userId: userId)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            );
          }
          final notifications = snap.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.taupe,
                      size: 40,
                    ),
                    const SizedBox(height: CsSpacing.md),
                    Text(
                      'Nothing yet',
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.forestGreen,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      'Friend requests and updates will appear here.',
                      textAlign: TextAlign.center,
                      style: CsTypography.body.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.pageHorizontal,
              vertical: CsSpacing.md,
            ),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _NotificationRow(
              notification: notifications[i],
              onAccept: () => _accept(notifications[i]),
              onDecline: () => _decline(notifications[i]),
              onTapOther: notifications[i].otherUserId == null
                  ? null
                  : () => _openProfile(notifications[i].otherUserId!),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTapOther;

  const _NotificationRow({
    required this.notification,
    required this.onAccept,
    required this.onDecline,
    required this.onTapOther,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: CsSpacing.md, right: CsSpacing.xs),
        child: _UnreadDot(visible: !notification.isRead),
      ),
      Expanded(child: _content(context)),
    ],
  );

  Widget _content(BuildContext context) {
    switch (notification.type) {
      case AppNotificationType.friendRequestReceived:
        return IdentityRow(
          label: notification.otherLabel,
          username: notification.otherUsername,
          avatarUrl: notification.otherAvatarUrl,
          onTap: onTapOther,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onDecline,
                child: Text(
                  'Decline',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.taupe,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAccept,
                child: Text(
                  'Accept',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case AppNotificationType.friendRequestAccepted:
        return IdentityRow(
          label: notification.otherLabel,
          username: null,
          avatarUrl: notification.otherAvatarUrl,
          onTap: onTapOther,
          trailing: Text(
            'Accepted',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        );
      case AppNotificationType.missingListingAdded:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: AppColors.forestGreen,
                size: 20,
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Text(
                  '${notification.listingName ?? 'A place you reported'} '
                  '${notification.listingCity != null ? "in ${notification.listingCity}" : ""} '
                  'has been added.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _UnreadDot extends StatelessWidget {
  final bool visible;
  const _UnreadDot({required this.visible});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 8,
    height: 8,
    child: visible
        ? const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
          )
        : null,
  );
}
