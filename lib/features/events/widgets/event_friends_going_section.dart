import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/friendship.dart';
import '../../friends/friend_profile_screen.dart';
import '../../friends/widgets/identity_row.dart';
import '../event_friends_going_list_screen.dart';

/// How many attendees to preview before deferring to "View all" — Community/
/// Friends Step 1A's own explicit cap. Distinct from
/// FriendProfileScreen's unrelated `_previewLimit` of 4 for its own
/// VISITED/WISHLIST/GOING sections — the two are not meant to stay in
/// lockstep, this section has its own, separately-specified limit.
const _previewLimit = 3;

/// "FRIENDS GOING" on Event Detail (Community/Friends Step 1A): the
/// accepted friends whose event_attendance row for this event RLS already
/// allows the viewer to see — see the `friendsGoingToEvent` view-model
/// function's own doc comment for the full authority chain. Entirely
/// distinct from `get_event_attendance_count`'s global, identity-free,
/// k-anonymized count — that RPC is not called and not modified anywhere
/// in this feature; this section only ever shows named friends, never a
/// total headcount.
///
/// The caller (EventDetailScreen) is responsible for never constructing
/// this widget with an empty list — a still-loading, errored, or
/// genuinely empty result must omit the section entirely rather than
/// rendering it with nothing to show (never "0 friends going").
class EventFriendsGoingSection extends StatelessWidget {
  final String eventTitle;
  final List<Friendship> friends;

  const EventFriendsGoingSection({
    super.key,
    required this.eventTitle,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    final preview = friends.take(_previewLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FRIENDS GOING',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            if (friends.length > _previewLimit)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventFriendsGoingListScreen(
                      eventTitle: eventTitle,
                      friends: friends,
                    ),
                  ),
                ),
                child: Text(
                  'View all',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: CsSpacing.sm),
        for (final friend in preview)
          IdentityRow(
            label: friend.label,
            username: friend.username,
            avatarUrl: friend.avatarUrl,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FriendProfileScreen(userId: friend.friendId),
              ),
            ),
          ),
      ],
    );
  }
}
