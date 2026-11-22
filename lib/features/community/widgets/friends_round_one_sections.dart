import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/friendship.dart';
import '../../../models/passport_venue.dart';
import '../../../models/visit.dart' show formatOverall;
import '../../events/event_date_format.dart';
import '../../friends/friend_profile_screen.dart'
    show openFriendEvent, openFriendVenue;
import '../../friends/friends_together_data.dart';
import '../../trips/trip_detail_screen.dart';
import '../../trips/widgets/trip_card.dart' show formatTripDateRange;
import '../friends_plans.dart';
import 'community_shared.dart';

/// The rows Friends round one (2026-11-22) adds to Community → Friends:
/// Plans in motion, Coming up with friends, Loved by your friends and the
/// wines friends would drink again. Same deep-green canvas and row rhythm
/// as [FriendActivityRow]; gold only on stars and Keys, never on text.

String _cityOf(PassportVenue venue) => switch (venue) {
  RestaurantVenue(:final restaurant) => restaurant.cityName,
  HotelVenue(:final hotel) => hotel.cityName,
};

/// A row with a leading avatar or thumbnail, a small-caps eyebrow, a serif
/// title and up to two quiet lines.
class _FriendsRow extends StatelessWidget {
  final Widget leading;
  final String? eyebrow;
  final String title;
  final String? meta;
  final String? note;
  final String semanticLabel;
  final VoidCallback onTap;

  const _FriendsRow({
    required this.leading,
    required this.title,
    required this.semanticLabel,
    required this.onTap,
    this.eyebrow,
    this.meta,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: CsTypography.editorialLabel().copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.ivory,
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note!.toUpperCase(),
                        style: CsTypography.editorialLabel().copyWith(
                          color: AppColors.ivory,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _avatar(Friendship friend, {double size = 40}) => CommunityAvatarCircle(
  initials: initialsFor(friend.label),
  avatarUrl: friend.avatarUrl,
  size: size,
);

/// One plan: an invite with a friend, or a trip with friends.
class FriendPlanRow extends StatelessWidget {
  final FriendPlan plan;
  const FriendPlanRow({super.key, required this.plan});

  @override
  Widget build(BuildContext context) => switch (plan) {
    InviteFriendPlan(:final friend, :final venue, :final eyebrow) =>
      _FriendsRow(
        leading: _avatar(friend),
        eyebrow: eyebrow,
        title: venue.name,
        meta: _cityOf(venue),
        semanticLabel: '$eyebrow, ${venue.name}, ${_cityOf(venue)}',
        onTap: () => openFriendVenue(context, venue),
      ),
    TripFriendPlan(:final trip, :final companions, :final companionsLine) =>
      _FriendsRow(
        leading: _avatar(companions.first),
        eyebrow: 'Trip',
        title: trip.title,
        meta: '${formatTripDateRange(trip)} · $companionsLine',
        semanticLabel:
            'Trip, ${trip.title}, ${formatTripDateRange(trip)}, '
            '$companionsLine',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
        ),
      ),
  };
}

/// One upcoming event with the friends going to or interested in it.
class EventWithFriendsRow extends StatelessWidget {
  final EventWithFriends item;
  const EventWithFriendsRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final city = event.city?.trim();
    final date = formatEventDateRange(event);
    final meta = [
      city == null || city.isEmpty ? date : '$date · $city',
      item.friendsLine,
    ].join('\n');
    return _FriendsRow(
      leading: VenueThumbnail(imageUrl: event.imageUrl, size: 56),
      title: event.name,
      meta: meta,
      note: item.mineLine,
      semanticLabel: [
        event.name,
        date,
        ?city,
        item.friendsLine,
        ?item.mineLine,
      ].join(', '),
      onTap: () => openFriendEvent(context, event.id),
    );
  }
}

/// One venue friends scored highly, with each friend's score.
class LovedByFriendsRow extends StatelessWidget {
  final VenueLovedByFriends item;
  const LovedByFriendsRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final venue = item.venue;
    final scores = [
      for (final s in item.scores.take(3))
        '${s.friend.label} ${formatOverall(s.score)}',
    ].join(' · ');
    return _FriendsRow(
      leading: VenueThumbnail(
        imageUrl: venue.cardImageUrl,
        framing: venue.cardFraming,
        size: 56,
      ),
      title: venue.name,
      meta: '${_cityOf(venue)}\n$scores',
      semanticLabel: '${venue.name}, ${_cityOf(venue)}, $scores',
      onTap: () => openFriendVenue(context, venue),
    );
  }
}

/// A wine a friend would drink again: the wine, who, and their note.
class FriendAgainWineRow extends StatelessWidget {
  final FriendAgainWine item;
  const FriendAgainWineRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final w = item.wine.wine;
    final title = [w.title, ?w.yearLabel].join(' ');
    final note = w.tastingNote?.trim();
    final who = '${item.friend.label} would drink it again';
    return Semantics(
      label: [title, ?w.subtitle, who, ?note].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(item.friend, size: 32),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [?w.subtitle, who].join(' · '),
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: CsTypography.editorialTitle(
                        size: 15,
                        italic: true,
                      ).copyWith(color: AppColors.secondaryOnDark),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every upcoming event with friends, from "All N events".
class EventsWithFriendsScreen extends StatelessWidget {
  final List<EventWithFriends> items;
  const EventsWithFriendsScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    appBar: AppBar(
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      elevation: 0,
      title: Text(
        'Coming up with friends',
        style: CsTypography.editorialTitle(
          size: 20,
        ).copyWith(color: AppColors.textOnDark),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.sm,
        CsSpacing.pageHorizontal,
        CsSpacing.xxl,
      ),
      children: [for (final item in items) EventWithFriendsRow(item: item)],
    ),
  );
}
