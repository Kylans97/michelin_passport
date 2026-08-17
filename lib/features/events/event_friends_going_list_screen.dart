import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../models/friendship.dart';
import '../friends/friend_profile_screen.dart';
import '../friends/widgets/identity_row.dart';

/// "View all" destination for Event Detail's FRIENDS GOING section
/// (Community/Friends Step 1A). [EventFriendsGoingSection] has already
/// resolved the full, sorted, self-excluded friend list before this screen
/// is ever pushed, so this makes no query of its own — there is nothing
/// left to fetch.
///
/// Built fresh with the corrected safe-area pattern (deep-green
/// Scaffold background continuing through the iOS status bar behind a
/// scoped AnnotatedRegion, explicit ivory ColoredBox for the list body)
/// rather than reusing friend_activity_list_screen.dart's shell — that
/// file's three screens predate the UI Polish safe-area fix and still
/// carry the ivory-strip-behind-the-status-bar bug; a new screen must not
/// inherit it.
///
/// Green Token Consistency Migration: AppColors.deepGreen, not
/// forestGreen — the canonical primary brand dark surface.
class EventFriendsGoingListScreen extends StatelessWidget {
  final String eventTitle;
  final List<Friendship> friends;

  const EventFriendsGoingListScreen({
    super.key,
    required this.eventTitle,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.base,
                  CsSpacing.sm,
                  CsSpacing.base,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: EditorialBackButton(color: AppColors.ivory),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FRIENDS GOING',
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eventTitle,
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.ivory,
                child: SafeArea(
                  top: false,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsSpacing.pageHorizontal,
                      vertical: CsSpacing.lg,
                    ).copyWith(bottom: CsSpacing.xxl),
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const _RowDivider(),
                    itemBuilder: (context, i) => IdentityRow(
                      label: friends[i].label,
                      username: friends[i].username,
                      avatarUrl: friends[i].avatarUrl,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FriendProfileScreen(userId: friends[i].friendId),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.75, color: AppColors.taupe.withValues(alpha: 0.55));
}
