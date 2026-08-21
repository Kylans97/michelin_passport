import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/friendship.dart';
import '../../friends/friend_profile_screen.dart';
import '../../friends/widgets/identity_row.dart';
import '../event_friends_interested_list_screen.dart';

/// Matches [EventFriendsGoingSection]'s own preview cap exactly — see
/// that class's doc comment for why this isn't shared with
/// FriendProfileScreen's own, separately-specified `_previewLimit`.
const _previewLimit = 3;

/// "FRIENDS INTERESTED" on Event Detail (Events V2 Step 7) — a small
/// parallel component to [EventFriendsGoingSection] rather than a
/// generalized shared widget: the two sections' only difference is a
/// heading string and a drilldown destination, but duplicating this
/// small, already-tested component costs nothing and keeps Friends
/// Going's own working code path completely untouched by this step,
/// matching this codebase's established "small parallel component for a
/// genuinely different concept" precedent (see PrivateChefHero's own doc
/// comment for the same reasoning applied elsewhere).
///
/// Sourced from confirmed-friends-visible Interested rows only — Events
/// V2 Step 7 changed `visibilityForIntent(EventIntentStatus.interested)`
/// from private to friends, so this reads through the exact same RLS
/// path Friends Going already uses (`event_attendance_select`), just
/// filtered to `status = 'interested'`.
///
/// The caller (EventDetailScreen) is responsible for never constructing
/// this widget with an empty list — see EventFriendsGoingSection's own
/// doc comment for the identical rule.
class EventFriendsInterestedSection extends StatelessWidget {
  final String eventTitle;
  final List<Friendship> friends;

  const EventFriendsInterestedSection({
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
              'FRIENDS INTERESTED',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            if (friends.length > _previewLimit)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventFriendsInterestedListScreen(
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
