import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/event_attendance.dart';
import '../../../models/passport_venue.dart';
import '../../../models/photo_framing.dart';
import '../../events/event_date_format.dart';
import '../../friends/friend_profile_screen.dart'
    show FriendVenueVisit, openFriendEvent, openVisitDetail;
import '../friends_activity.dart';
import 'community_shared.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A visit's calendar date — date only, since no clock time exists for it.
/// The year is left off within the current year.
String formatActivityDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final base = '${date.day} ${_monthNames[date.month - 1]}';
  return date.year == today.year ? base : '$base ${date.year}';
}

String _ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// One milestone as a short small-caps line, e.g. "FIRST IN JAPAN".
String milestoneLabel(
  FriendMilestone milestone,
  Map<String, String> countryNameByCode,
) => switch (milestone) {
  FirstInCountryMilestone(:final countryCode) =>
    'First in ${countryNameByCode[countryCode] ?? countryCode}',
  StarredCountMilestone(:final count) =>
    '${_ordinal(count)} MICHELIN-starred restaurant',
  FirstThreeStarMilestone() => 'First three-star restaurant',
};

/// The sentence for [activity], split so the names can be set in ivory:
/// (friend, verb, subject).
(String, String, String) activitySentence(FriendActivity activity) =>
    switch (activity) {
      VisitActivity(:final friend, :final venue) => (
        friend.label,
        venue is HotelVenue ? 'stayed at' : 'visited',
        venue.name,
      ),
      EventIntentActivity(:final friend, :final event, :final status) => (
        friend.label,
        status == EventIntentStatus.going ? 'is going to' : 'is interested in',
        event.name,
      ),
      EventStampActivity(:final friend, :final event) => (
        friend.label,
        'collected a Passport stamp at',
        event.name,
      ),
    };

/// One Friends' Activity item on Community's deep-green canvas: the
/// friend's avatar, one sentence, a quiet metadata line, any milestones
/// in small caps, and the venue or event photo. Tapping opens what the
/// item is about — the friend's visit, or the event — through the same
/// screens Friend Profile already uses, never a social wrapper.
class FriendActivityRow extends StatelessWidget {
  final FriendActivity activity;
  final Map<String, String> countryNameByCode;

  const FriendActivityRow({
    super.key,
    required this.activity,
    this.countryNameByCode = const {},
  });

  String get _meta => switch (activity) {
    VisitActivity(:final visit) => [
      if (visit.rating != null) '${visit.rating}/10',
      formatActivityDate(visit.visitedOn),
    ].join(' · '),
    EventIntentActivity(:final event) => formatEventDateRange(event),
    EventStampActivity(:final event, :final rating) => [
      if (rating != null) '$rating/10',
      formatEventDateRange(event),
    ].join(' · '),
  };

  String? get _imageUrl => switch (activity) {
    VisitActivity(:final venue) => venue.cardImageUrl,
    EventIntentActivity(:final event) => event.imageUrl,
    EventStampActivity(:final event) => event.imageUrl,
  };

  void _open(BuildContext context) => switch (activity) {
    VisitActivity(:final venue, :final visit) => openVisitDetail(
      context,
      FriendVenueVisit(venue, visit),
    ),
    EventIntentActivity(:final event) => openFriendEvent(context, event.id),
    EventStampActivity(:final event) => openFriendEvent(context, event.id),
  };

  @override
  Widget build(BuildContext context) {
    final (who, verb, what) = activitySentence(activity);
    final milestones = switch (activity) {
      VisitActivity(:final milestones) => [
        for (final m in milestones) milestoneLabel(m, countryNameByCode),
      ],
      _ => const <String>[],
    };
    final meta = _meta;
    final friend = activity.friend;

    return Semantics(
      button: true,
      label: ['$who $verb $what', meta, ...milestones].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunityAvatarCircle(
                  initials: initialsFor(friend.label),
                  avatarUrl: friend.avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: CsTypography.body.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                          children: [
                            TextSpan(
                              text: who,
                              style: CsTypography.bodyMedium.copyWith(
                                color: AppColors.ivory,
                              ),
                            ),
                            TextSpan(text: ' $verb '),
                            TextSpan(
                              text: what,
                              style: CsTypography.bodyMedium.copyWith(
                                color: AppColors.ivory,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                      if (milestones.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          milestones.join(' · ').toUpperCase(),
                          style: CsTypography.editorialLabel().copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CsSpacing.md),
                VenueThumbnail(
                  imageUrl: _imageUrl,
                  size: 48,
                  framing: switch (activity) {
                    VisitActivity(:final venue) => venue.cardFraming,
                    _ => PhotoFraming.center,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
