import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../events/event_detail_screen.dart';
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
import '../../data/repositories/planned_trips_repository.dart';
import '../../data/repositories/venue_invite_repository.dart';
import '../../models/app_notification.dart';
import '../friends/friend_profile_screen.dart';
import '../friends/widgets/identity_row.dart';
import '../../core/analytics/screen_usage.dart';
import 'push_prompt_sheet.dart';
import 'push_service.dart';

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
  late final _tripsRepo = PlannedTripsRepository(Supabase.instance.client);
  late final AnalyticsService _analytics =
      widget.analytics ?? SupabaseAnalyticsService(Supabase.instance.client);

  late Future<List<AppNotification>> _future;

  // Older pages, appended as the list reaches its end — see
  // NotificationsRepository.getNotifications. [_load] starts over.
  List<AppNotification> _older = const [];
  bool _hasMore = false;
  bool _loadingMore = false;
  int _serverOffset = 0;

  @override
  void initState() {
    super.initState();
    trackScreenOpened(AnalyticsScreen.notifications);
    _load();
  }

  void _load() {
    setState(() {
      _older = const [];
      _hasMore = false;
      _future = _notificationsRepo.getNotifications().then((page) {
        // Fire-and-forget: the caller doesn't need to wait for this to
        // render the list, and a failure here shouldn't block viewing
        // notifications that already loaded successfully. Marks every
        // unread row, paged in or not, exactly as before paging.
        _notificationsRepo.markAllAsRead().catchError((_) {});
        _hasMore = page.hasMore;
        _serverOffset = notificationsPageSize;
        return page.notifications;
      });
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await _notificationsRepo.getNotifications(
        offset: _serverOffset,
      );
      if (!mounted) return;
      setState(() {
        _older = [..._older, ...page.notifications];
        _hasMore = page.hasMore;
        _serverOffset += notificationsPageSize;
      });
    } catch (_) {
      // The list so far stays; reaching the end again retries.
    } finally {
      _loadingMore = false;
    }
  }

  AnalyticsEntityType? _inviteEntityType(AppNotification n) =>
      switch (n.inviteVenueType) {
        'restaurant' => AnalyticsEntityType.restaurant,
        'hotel' => AnalyticsEntityType.hotel,
        _ => null,
      };

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Both RPCs raise when the request/invite is no longer pending (answered
  // elsewhere — a friend request can also be answered on FriendsScreen's
  // Requests tab). Previously uncaught, so a tap did nothing visible; now
  // it says so and reloads, which brings the row's current status in.
  Future<void> _accept(AppNotification n) async {
    try {
      switch (n.type) {
        case AppNotificationType.friendRequestReceived:
          await _friendRepo.acceptRequest(n.subjectId);
          if (mounted) PushService.instance.askAfter(context, const FriendsPrompt());
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
        case AppNotificationType.tripInviteReceived:
          await _tripsRepo.respondToTripInvite(
            memberId: n.subjectId,
            accept: true,
          );
        default:
          return;
      }
    } catch (_) {
      _showError('Could not accept. Please try again.');
    }
    _load();
  }

  Future<void> _decline(AppNotification n) async {
    try {
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
        case AppNotificationType.tripInviteReceived:
          await _tripsRepo.respondToTripInvite(
            memberId: n.subjectId,
            accept: false,
          );
        default:
          return;
      }
    } catch (_) {
      _showError('Could not decline. Please try again.');
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
          final notifications = [...?snap.data, ..._older];
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
            itemCount: notifications.length + (_hasMore ? 1 : 0),
            // A hairline from the text column on, so each notification
            // reads as one unit without boxing the list in.
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(left: 14 + 44 + CsSpacing.md),
              child: Divider(height: 1, color: AppColors.subtleBorderLight),
            ),
            itemBuilder: (_, i) => i == notifications.length
                ? _LoadMoreRow(onVisible: _loadMore)
                : _NotificationRow(
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

/// The end of a list with older pages: asks for the next one as soon as
/// it's built (i.e. scrolled into view) and shows a quiet spinner meanwhile.
class _LoadMoreRow extends StatefulWidget {
  final Future<void> Function() onVisible;

  const _LoadMoreRow({required this.onVisible});

  @override
  State<_LoadMoreRow> createState() => _LoadMoreRowState();
}

class _LoadMoreRowState extends State<_LoadMoreRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVisible());
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: CsSpacing.md),
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          color: AppColors.forestGreen,
          strokeWidth: 1.5,
        ),
      ),
    ),
  );
}

/// Every notification row has one shape (tidied 2026-10-31 — rows used
/// to differ by a few points each, and some put their status beside the
/// name and others below it):
///
///   [unread dot] [44pt avatar or icon] [title / what happened / status]
///
/// The text column always starts at the same x, so names, descriptions,
/// quotes and buttons line up from one row to the next.
class _NotificationTile extends StatelessWidget {
  final bool unread;
  final Widget leading;
  final String? title;
  final String description;
  final String? quote;
  final Widget? footer;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.unread,
    required this.leading,
    this.title,
    required this.description,
    this.quote,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _UnreadDot(visible: unread),
            ),
          ),
          leading,
          const SizedBox(width: CsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                ] else
                  // No name line: centre a one-line description on the
                  // 44pt leading circle instead of hanging at its top.
                  const SizedBox(height: 11),
                Text(
                  description,
                  style: CsTypography.body.copyWith(
                    color: title != null
                        ? AppColors.textSecondary
                        : AppColors.forestGreen,
                  ),
                ),
                if (quote != null && quote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${quote!}"',
                    style: CsTypography.body.copyWith(
                      color: AppColors.taupe,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: CsSpacing.xs),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
        highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
        child: body,
      ),
    );
  }
}

/// An icon in the same 44pt circle a member's avatar sits in, for the
/// notifications that aren't from a person.
class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle(this.icon);

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.warmWhite,
      border: Border.all(color: AppColors.subtleBorderLight),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: AppColors.forestGreen, size: 20),
  );
}

/// A quiet status line under a notification ("You accepted").
Widget _statusText(String text) =>
    Text(text, style: CsTypography.metadata.copyWith(color: AppColors.taupe));

/// Decline / accept, under the description, left-aligned with the text.
Widget _answerButtons({
  required VoidCallback onDecline,
  required VoidCallback onAccept,
  String acceptLabel = 'Accept',
}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    TextButton(
      onPressed: onAccept,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        acceptLabel,
        style: CsTypography.metadata.copyWith(
          color: AppColors.forestGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    const SizedBox(width: CsSpacing.lg),
    TextButton(
      onPressed: onDecline,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Decline',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      ),
    ),
  ],
);

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

  bool get _unread => !notification.isRead;

  Widget get _avatar => IdentityAvatar(
    label: notification.otherLabel,
    avatarUrl: notification.otherAvatarUrl,
  );

  void _openEvent(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(eventId: notification.subjectId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final n = notification;
    switch (n.type) {
      // Accept/Decline only while the request is pending, then what became
      // of it. 'blocked' and a friendship that no longer exists show no
      // status rather than a guess at why.
      case AppNotificationType.friendRequestReceived:
        return _NotificationTile(
          unread: _unread,
          leading: _avatar,
          title: n.otherLabel,
          description: 'Sent you a friend request',
          onTap: onTapOther,
          footer: n.friendRequestIsPending
              ? _answerButtons(onDecline: onDecline, onAccept: onAccept)
              : switch (n.friendshipStatus) {
                  'accepted' => _statusText('You accepted'),
                  'declined' => _statusText('You declined'),
                  _ => null,
                },
        );
      case AppNotificationType.friendRequestAccepted:
        return _NotificationTile(
          unread: _unread,
          leading: _avatar,
          title: n.otherLabel,
          description: 'Accepted your friend request',
          onTap: onTapOther,
        );
      case AppNotificationType.missingListingAdded:
        return _NotificationTile(
          unread: _unread,
          leading: const _IconCircle(Icons.storefront_outlined),
          description:
              '${n.listingName ?? 'A place you reported'}'
              '${n.listingCity != null ? ' in ${n.listingCity}' : ''}'
              ' has been added.',
        );
      case AppNotificationType.venueInviteReceived:
      case AppNotificationType.venueInviteAccepted:
      case AppNotificationType.venueInviteDeclined:
        return _venueInvite();
      case AppNotificationType.venueClaimReceived:
      case AppNotificationType.venueClaimApproved:
      case AppNotificationType.venueClaimRejected:
        return _venueClaim();
      case AppNotificationType.venueAboutApproved:
      case AppNotificationType.venueAboutRejected:
      case AppNotificationType.venuePhotoApproved:
      case AppNotificationType.venuePhotoRejected:
        return _venueSubmission();
      case AppNotificationType.eventApproved:
      case AppNotificationType.eventRejected:
        final isRejected = n.type == AppNotificationType.eventRejected;
        final name = n.eventName ?? 'Your event';
        final at = n.eventVenueName == null ? '' : ' at ${n.eventVenueName}';
        // Approved: it's live, and tapping opens it. Not approved: the
        // reviewer's note; the venue edits and resubmits from My venues.
        return _NotificationTile(
          unread: _unread,
          leading: _IconCircle(
            isRejected
                ? Icons.event_busy_outlined
                : Icons.event_available_outlined,
          ),
          description: isRejected
              ? '"$name"$at was not approved.'
              : '"$name"$at is now live.',
          quote: isRejected ? n.eventReviewNote?.trim() : null,
          onTap: isRejected ? null : () => _openEvent(context),
        );
      case AppNotificationType.followedVenueEvent:
        // A venue the person follows published an event; tapping opens
        // it, the same as the push for it does.
        final venue = n.eventVenueName ?? 'A venue you follow';
        return _NotificationTile(
          unread: _unread,
          leading: const _IconCircle(Icons.event_outlined),
          description: n.eventName == null
              ? '$venue announced a new event.'
              : '$venue announced "${n.eventName}".',
          onTap: () => _openEvent(context),
        );
      case AppNotificationType.tripInviteReceived:
      case AppNotificationType.tripInviteAccepted:
        return _tripInvite();
    }
  }

  // An expired invite is never hidden — only its buttons give way to a
  // neutral "Expired", by explicit product requirement (a vanished
  // invite reads as "I missed something", not "this lapsed").
  Widget _venueInvite() {
    final n = notification;
    final venueName = n.inviteVenueName ?? 'a place';
    final city = n.inviteVenueCity;
    final isReceived = n.type == AppNotificationType.venueInviteReceived;
    Widget? status;
    if (isReceived) {
      status = switch (n.inviteStatus) {
        'pending' when n.inviteIsExpired => _statusText('Expired'),
        'pending' => _answerButtons(onDecline: onDecline, onAccept: onAccept),
        'accepted' => _statusText('You accepted'),
        'declined' => _statusText('You declined'),
        _ => null,
      };
    }
    return _NotificationTile(
      unread: _unread,
      leading: _avatar,
      title: n.otherLabel,
      description: switch (n.type) {
        AppNotificationType.venueInviteReceived =>
          'Suggests going to $venueName${city != null ? ' in $city' : ''}',
        AppNotificationType.venueInviteAccepted => 'Said yes to $venueName',
        _ => "Can't make it to $venueName",
      },
      quote: isReceived ? n.inviteNote?.trim() : null,
      footer: status,
      onTap: onTapOther,
    );
  }

  // A trip invitation, or a friend saying yes to one. The invitee
  // answers here (respond_to_trip_invite) or from the top of Trips.
  Widget _tripInvite() {
    final n = notification;
    final trip = n.tripTitle ?? 'a trip';
    final isReceived = n.type == AppNotificationType.tripInviteReceived;
    Widget? status;
    if (isReceived) {
      status = n.tripMemberStatus == 'pending'
          ? _answerButtons(
              onDecline: onDecline,
              onAccept: onAccept,
              acceptLabel: 'Join trip',
            )
          : _statusText(switch (n.tripMemberStatus) {
              'accepted' => 'You joined',
              'declined' => 'You declined',
              _ => 'No longer open',
            });
    }
    return _NotificationTile(
      unread: _unread,
      leading: _avatar,
      title: n.otherLabel,
      description: isReceived ? 'Invited you to $trip' : 'Is coming on $trip',
      footer: status,
      onTap: onTapOther,
    );
  }

  // The claim lifecycle: a status update about the claimant's own
  // request, nothing to act on here. A rejected AND a blocked claim share
  // the same copy (see AppNotificationType.venueClaimRejected). Received
  // and rejected carry the one contact point a claimant has: the mailto
  // line.
  Widget _venueClaim() {
    final n = notification;
    final venueName = n.claimVenueName ?? 'the venue you claimed';
    final showContactLine =
        n.type == AppNotificationType.venueClaimReceived ||
        n.type == AppNotificationType.venueClaimRejected;
    return _NotificationTile(
      unread: _unread,
      leading: _IconCircle(switch (n.type) {
        AppNotificationType.venueClaimApproved => Icons.verified_outlined,
        AppNotificationType.venueClaimRejected => Icons.storefront_outlined,
        _ => Icons.hourglass_top_outlined,
      }),
      description: switch (n.type) {
        AppNotificationType.venueClaimReceived =>
          'Your claim for $venueName is being reviewed.',
        AppNotificationType.venueClaimApproved =>
          'Your claim for $venueName was approved — you can now manage '
              'its page.',
        _ => 'Your claim for $venueName was not approved.',
      },
      quote: n.type == AppNotificationType.venueClaimRejected
          ? n.claimReviewNote?.trim()
          : null,
      footer: showContactLine ? _ClaimContactLine(venueName: venueName) : null,
    );
  }

  // A manager's about text or photo was reviewed; a rejection carries the
  // reviewer's note inline, as nowhere else shows a submission's review.
  Widget _venueSubmission() {
    final n = notification;
    final venueName = n.submissionVenueName ?? 'your venue';
    final isPhoto =
        n.type == AppNotificationType.venuePhotoApproved ||
        n.type == AppNotificationType.venuePhotoRejected;
    final what = isPhoto ? 'photo' : 'about text';
    final isRejected =
        n.type == AppNotificationType.venueAboutRejected ||
        n.type == AppNotificationType.venuePhotoRejected;
    return _NotificationTile(
      unread: _unread,
      leading: _IconCircle(
        isRejected ? Icons.storefront_outlined : Icons.verified_outlined,
      ),
      description: isRejected
          ? 'Your $what for $venueName was not approved.'
          : 'Your $what for $venueName is now live.',
      quote: isRejected ? n.submissionReviewNote?.trim() : null,
    );
  }
}

class _ClaimContactLine extends StatelessWidget {
  final String venueName;
  const _ClaimContactLine({required this.venueName});

  Future<void> _emailUs() async {
    final uri = claimQuestionMailtoUri(venueName);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _emailUs,
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
  );
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
