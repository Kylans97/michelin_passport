import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_friends_stack.dart';
import '../../../data/repositories/friend_activity_repository.dart';
import '../../../models/friendship.dart';
import '../../community/widgets/community_shared.dart' show initialsFor;
import '../friend_profile_screen.dart';
import 'identity_row.dart';

/// "Anna & Bas have been here" — the friends who have been to this
/// restaurant or hotel, as a few faces and one line, near the top of
/// Restaurant/Hotel Detail. Deliberately no scores (product owner,
/// 2026-10-30): a friend's verdict is one tap further, on their profile,
/// so the venue page stays calm. One friend opens their profile directly;
/// several open a short list first.
///
/// Loads itself and renders nothing until there is at least one friend —
/// never "0 friends", never a spinner on the venue page. Only visits a
/// friend marked `friends` count (see
/// [FriendActivityRepository.loadFriendsWhoVisited]).
class VenueFriendsBeenRow extends StatefulWidget {
  /// `restaurant` or `hotel`, as in `visits.entity_type`.
  final String entityType;
  final String entityId;

  /// Test seam; defaults to [FriendActivityRepository].
  final Future<List<Friendship>> Function()? loadFriends;

  const VenueFriendsBeenRow({
    super.key,
    required this.entityType,
    required this.entityId,
    this.loadFriends,
  });

  @override
  State<VenueFriendsBeenRow> createState() => _VenueFriendsBeenRowState();
}

/// "Anna has been here", "Anna & Bas have been here", "Anna, Bas & 2 other
/// friends have been here".
String friendsBeenLabel(List<Friendship> friends) {
  final names = [for (final f in friends) f.label];
  return switch (names.length) {
    0 => '',
    1 => '${names[0]} has been here',
    2 => '${names[0]} & ${names[1]} have been here',
    3 => '${names[0]}, ${names[1]} & ${names[2]} have been here',
    _ =>
      '${names[0]}, ${names[1]} & ${names.length - 2} other friends '
          'have been here',
  };
}

class _VenueFriendsBeenRowState extends State<VenueFriendsBeenRow> {
  List<Friendship> _friends = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final load =
          widget.loadFriends ??
          () => FriendActivityRepository(Supabase.instance.client)
              .loadFriendsWhoVisited(
                entityType: widget.entityType,
                entityId: widget.entityId,
              );
      final friends = await load();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {
      // Social proof is optional: a failure just leaves the row out.
    }
  }

  void _openProfile(BuildContext context, Friendship friend) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FriendProfileScreen(userId: friend.friendId),
    ),
  );

  void _onTap(BuildContext context) {
    if (_friends.length == 1) {
      _openProfile(context, _friends.single);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ivory,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            0,
            CsSpacing.pageHorizontal,
            CsSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FRIENDS WHO'VE BEEN",
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final friend in _friends)
                      IdentityRow(
                        label: friend.label,
                        username: friend.username,
                        avatarUrl: friend.avatarUrl,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openProfile(context, friend);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_friends.isEmpty) return const SizedBox.shrink();
    final label = friendsBeenLabel(_friends);
    return Padding(
      padding: const EdgeInsets.only(top: CsSpacing.md),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Flexible(
                  child: FriendsStack(
                    friends: [
                      for (final f in _friends)
                        CsFriendAvatar(
                          id: f.friendId,
                          initials: initialsFor(f.label),
                          photoUrl: f.avatarUrl,
                        ),
                    ],
                    label: label,
                    size: 30,
                    ringColor: AppColors.ivory,
                    labelColor: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(width: CsSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.taupe,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
