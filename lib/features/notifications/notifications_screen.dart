import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/supabase_analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/venue_invite_repository.dart';
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
  // Optional DI seam, matching NewsArticleDetailScreen's established
  // convention — defaults to the real SupabaseAnalyticsService so a test
  // can supply a fake without needing a live Supabase session.
  final AnalyticsService? analytics;

  const NotificationsScreen({super.key, this.analytics});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final _notificationsRepo = NotificationsRepository(
    Supabase.instance.client,
  );
  late final _friendRepo = FriendshipRepository(Supabase.instance.client);
  late final _venueInviteRepo = VenueInviteRepository(Supabase.instance.client);
  late final AnalyticsService _analytics =
      widget.analytics ?? SupabaseAnalyticsService(Supabase.instance.client);

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

  AnalyticsEntityType? _inviteEntityType(AppNotification n) =>
      switch (n.inviteVenueType) {
        'restaurant' => AnalyticsEntityType.restaurant,
        'hotel' => AnalyticsEntityType.hotel,
        _ => null,
      };

  Future<void> _accept(AppNotification n) async {
    switch (n.type) {
      case AppNotificationType.friendRequestReceived:
        await _friendRepo.acceptRequest(n.subjectId);
      case AppNotificationType.venueInviteReceived:
        await _venueInviteRepo.acceptInvite(n.subjectId);
        _analytics.track(
          AnalyticsEvent.venueInviteAccepted,
          AnalyticsProperties(
            inviteId: n.subjectId,
            entityType: _inviteEntityType(n),
            entityId: n.inviteVenueId,
          ),
        );
      default:
        return;
    }
    _load();
  }

  Future<void> _decline(AppNotification n) async {
    switch (n.type) {
      case AppNotificationType.friendRequestReceived:
        await _friendRepo.declineRequest(n.subjectId);
      case AppNotificationType.venueInviteReceived:
        await _venueInviteRepo.declineInvite(n.subjectId);
        _analytics.track(
          AnalyticsEvent.venueInviteDeclined,
          AnalyticsProperties(
            inviteId: n.subjectId,
            entityType: _inviteEntityType(n),
            entityId: n.inviteVenueId,
          ),
        );
      default:
        return;
    }
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
      case AppNotificationType.venueInviteReceived:
      case AppNotificationType.venueInviteAccepted:
      case AppNotificationType.venueInviteDeclined:
        return _VenueInviteContent(
          notification: notification,
          onTapOther: onTapOther,
          onAccept: onAccept,
          onDecline: onDecline,
        );
    }
  }
}

/// The three venue-invite notification types share one layout: the other
/// participant's identity, then an indented line describing what
/// happened, then (received only) either Accept/Decline or a status
/// label. An expired invite is never hidden or removed — only its
/// Accept/Decline buttons are replaced with a neutral "Expired" label,
/// per explicit product requirement (an invite that silently vanished
/// would read as "I missed something", not "this lapsed").
class _VenueInviteContent extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTapOther;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _VenueInviteContent({
    required this.notification,
    required this.onTapOther,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final venueName = notification.inviteVenueName ?? 'a place';
    final city = notification.inviteVenueCity;
    final note = notification.inviteNote?.trim();
    final isReceived = notification.type == AppNotificationType.venueInviteReceived;

    final description = switch (notification.type) {
      AppNotificationType.venueInviteReceived =>
        'Suggests going to $venueName${city != null ? ' in $city' : ''}',
      AppNotificationType.venueInviteAccepted => 'Said yes to $venueName',
      AppNotificationType.venueInviteDeclined => "Can't make it to $venueName",
      _ => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IdentityRow(
          label: notification.otherLabel,
          username: isReceived ? notification.otherUsername : null,
          avatarUrl: notification.otherAvatarUrl,
          onTap: onTapOther,
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 56,
            bottom: CsSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: CsTypography.body.copyWith(color: AppColors.forestGreen),
              ),
              if (isReceived && note != null && note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '"$note"',
                  style: CsTypography.body.copyWith(
                    color: AppColors.taupe,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (isReceived) ...[
                const SizedBox(height: 6),
                _receivedStatus(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _receivedStatus(BuildContext context) {
    switch (notification.inviteStatus) {
      case 'pending':
        if (notification.inviteIsExpired) {
          return Text(
            'Expired',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onDecline,
              child: Text(
                'Decline',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
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
        );
      case 'accepted':
        return Text(
          'You accepted',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        );
      case 'declined':
        return Text(
          'You declined',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        );
      default:
        return const SizedBox.shrink();
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
