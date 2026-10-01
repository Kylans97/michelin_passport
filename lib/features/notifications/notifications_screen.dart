import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/supabase_analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/mailto_uri.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/venue_invite_repository.dart';
import '../../models/app_notification.dart';
import '../friends/friend_profile_screen.dart';
import '../friends/widgets/identity_row.dart';

/// The one venue-ops inbox this app has — reviewed manually alongside
/// whatever it's about. Originally just claim questions (PART 1 of the
/// venue-claim-hardening work this belongs to); VenueManagementScreen's
/// own contact line now sends here too, for the same reason: it's the
/// one place a claimed venue's manager can already be told a person will
/// actually read what they send.
const _kClaimQuestionsEmail = 'claimedvenues@mantelier.app';

/// Pulled out to a top-level, `@visibleForTesting` function — same reason
/// as VenueClaimRepository.claimConflictMessage: this codebase has no
/// existing pattern for pumping a Supabase-eager screen's private row
/// widgets in a test (see notifications_screen_test.dart's own header
/// comment), so the one part worth asserting on directly — the venue
/// name actually reaching the mailto subject — is tested as pure Uri-
/// building logic instead. Encoding itself lives in mailtoUri
/// (core/utils/mailto_uri.dart) — see that function's own doc comment for
/// why `Uri.encodeComponent`, never `queryParameters:`; every mailto link
/// in this app, including VenueManagementScreen's own contact line,
/// builds through that one function rather than re-deriving this by hand.
@visibleForTesting
Uri claimQuestionMailtoUri(String venueName) =>
    mailtoUri(_kClaimQuestionsEmail, subject: 'Claim question — $venueName');

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
      case AppNotificationType.venueClaimReceived:
      case AppNotificationType.venueClaimApproved:
      case AppNotificationType.venueClaimRejected:
        return _VenueClaimContent(notification: notification);
      case AppNotificationType.venueAboutApproved:
      case AppNotificationType.venueAboutRejected:
      case AppNotificationType.venuePhotoApproved:
      case AppNotificationType.venuePhotoRejected:
        return _VenueSubmissionContent(notification: notification);
    }
  }
}

/// The three claim-lifecycle notifications share one read-only layout —
/// no Accept/Decline, no "other person": a claim is a status update about
/// the claimant's own request, not something to act on here (approval
/// happens on the Supabase dashboard, by explicit product decision).
/// [AppNotificationType.venueClaimRejected] covers both a rejected AND a
/// blocked claim with the identical copy — see that enum case's own doc
/// comment for why there's nothing here to tell the two apart.
///
/// The received/rejected rows only (not approved — nothing to ask once a
/// claim has succeeded) also carry a "Questions about your claim?" mailto
/// line, since this is the only screen in the app where a claimant sees
/// their claim's status at all — there is no separate "my claims" screen
/// to put it on instead, no in-app messaging, and no second email flow;
/// this is the one contact point.
class _VenueClaimContent extends StatelessWidget {
  final AppNotification notification;
  const _VenueClaimContent({required this.notification});

  Future<void> _emailUs(String venueName) async {
    final uri = claimQuestionMailtoUri(venueName);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueName = notification.claimVenueName ?? 'the venue you claimed';
    final description = switch (notification.type) {
      AppNotificationType.venueClaimReceived =>
        'Your claim for $venueName is being reviewed.',
      AppNotificationType.venueClaimApproved =>
        'Your claim for $venueName was approved — you can now manage its page.',
      AppNotificationType.venueClaimRejected =>
        'Your claim for $venueName was not approved.',
      _ => '',
    };
    final icon = switch (notification.type) {
      AppNotificationType.venueClaimApproved => Icons.verified_outlined,
      AppNotificationType.venueClaimRejected => Icons.storefront_outlined,
      _ => Icons.hourglass_top_outlined,
    };
    final showContactLine =
        notification.type == AppNotificationType.venueClaimReceived ||
        notification.type == AppNotificationType.venueClaimRejected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.forestGreen, size: 20),
          const SizedBox(width: CsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: CsTypography.body.copyWith(color: AppColors.forestGreen),
                ),
                if (showContactLine) ...[
                  const SizedBox(height: CsSpacing.xs),
                  GestureDetector(
                    onTap: () => _emailUs(venueName),
                    child: Text.rich(
                      TextSpan(
                        text: 'Questions about your claim? ',
                        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                        children: [
                          TextSpan(
                            text: _kClaimQuestionsEmail,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.forestGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four submission-review notification types share one read-only
/// layout, same shape as [_VenueClaimContent] — no Accept/Decline, no
/// "other person": each is a status update about the manager's own
/// submission, closing the loop notify_venue_submission_review() opened
/// (a trigger on venue_about_submissions/venue_photo_submissions going
/// pending -> approved/rejected — see that migration's own comment for
/// why there is no "received" counterpart here, unlike claims).
///
/// The rejection notification carries the reviewer's own note inline —
/// [AppNotification.submissionReviewNote] — the same place
/// [_VenueInviteContent] shows [AppNotification.inviteNote], rather than
/// pointing at a separate screen: there is no other screen a submission's
/// review state is shown on today.
class _VenueSubmissionContent extends StatelessWidget {
  final AppNotification notification;
  const _VenueSubmissionContent({required this.notification});

  @override
  Widget build(BuildContext context) {
    final venueName = notification.submissionVenueName ?? 'your venue';
    final isPhoto =
        notification.type == AppNotificationType.venuePhotoApproved ||
        notification.type == AppNotificationType.venuePhotoRejected;
    final what = isPhoto ? 'photo' : 'about text';
    final isRejected =
        notification.type == AppNotificationType.venueAboutRejected ||
        notification.type == AppNotificationType.venuePhotoRejected;
    final description = isRejected
        ? 'Your $what for $venueName was not approved.'
        : 'Your $what for $venueName is now live.';
    final icon = isRejected ? Icons.storefront_outlined : Icons.verified_outlined;
    final note = notification.submissionReviewNote?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.forestGreen, size: 20),
          const SizedBox(width: CsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: CsTypography.body.copyWith(color: AppColors.forestGreen),
                ),
                if (isRejected && note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$note"',
                    style: CsTypography.body.copyWith(
                      color: AppColors.taupe,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
