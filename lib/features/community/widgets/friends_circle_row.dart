import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/friendship.dart';
import 'community_shared.dart';

/// "YOUR CIRCLE": a horizontal row of the user's real, accepted friends
/// (`FriendshipRepository.getFriends()` — the exact same RPC/data
/// `FriendsScreen` already reads, no parallel source). Zero friends
/// renders a restrained [CommunityIvoryCard] onboarding card (COMMUNITY
/// V1 UI REFINEMENT — ivory content on the deep-green canvas, replacing
/// the earlier loose-text empty state) with a "Find friends" action
/// linking to the existing friend-search screen — never fake people,
/// never fake activity.
class FriendsCircleRow extends StatelessWidget {
  final List<Friendship> friends;
  final ValueChanged<Friendship> onTapFriend;
  final VoidCallback onSeeAll;
  final VoidCallback onFindPeople;

  const FriendsCircleRow({
    super.key,
    required this.friends,
    required this.onTapFriend,
    required this.onSeeAll,
    required this.onFindPeople,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return CommunityIvoryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your circle is still empty.',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              "Connect with other members to see what they're discovering.",
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.md),
            CommunityActionLink(
              label: 'Find friends',
              onTap: onFindPeople,
              light: true,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(width: CsSpacing.md),
            itemBuilder: (context, i) => _FriendCircleTile(
              friend: friends[i],
              onTap: () => onTapFriend(friends[i]),
            ),
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        CommunityActionLink(label: 'See all', onTap: onSeeAll),
      ],
    );
  }
}

class _FriendCircleTile extends StatelessWidget {
  final Friendship friend;
  final VoidCallback onTap;
  const _FriendCircleTile({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // First name only — the tile is compact, and a full display name would
    // rarely fit under a 56px circle anyway.
    final firstName = friend.label.split(' ').first;
    return Semantics(
      button: true,
      label: friend.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommunityAvatarCircle(
                    initials: initialsFor(friend.label),
                    avatarUrl: friend.avatarUrl,
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
