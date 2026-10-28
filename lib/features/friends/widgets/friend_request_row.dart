import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'identity_row.dart';

/// An incoming friend request with Decline/Accept — the one row shape
/// both FriendsScreen's Requests tab and NotificationsScreen's
/// friend_request_received row use, so the two can't drift apart.
///
/// The two buttons sit inline beside the name and stack (Decline above
/// Accept, right-aligned) only when they don't fit — at 320px with 1.6x
/// text the inline pair overflowed by 75px on both screens. IdentityRow
/// gives its trailing widget unbounded width (a non-flex child of its
/// Row), so this row measures its own width and caps the actions at
/// whatever is left after the avatar, the gaps and [_minNameWidth]; a
/// [Wrap] does the rest, and shrinks to the wider button once stacked
/// so the name gets the space back.
class FriendRequestRow extends StatelessWidget {
  final String label;
  final String? username;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FriendRequestRow({
    super.key,
    required this.label,
    this.username,
    this.avatarUrl,
    this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  // IdentityRow's fixed horizontal parts: InkWell padding (xs each side),
  // the 44px avatar, the md gap after it and the sm gap before trailing.
  static const double _identityChrome =
      CsSpacing.xs * 2 + 44 + CsSpacing.md + CsSpacing.sm;

  // Measured with the real Inter files (2026-10-28): the inline pair is
  // 145px at 1.0x text, so 56 keeps a 320px phone inline at normal text,
  // as it was before this widget, while anything tighter stacks.
  static const double _minNameWidth = 56;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actionsMaxWidth =
          (constraints.maxWidth - _identityChrome - _minNameWidth).clamp(
            0.0,
            double.infinity,
          );
      return IdentityRow(
        label: label,
        username: username,
        avatarUrl: avatarUrl,
        onTap: onTap,
        trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: actionsMaxWidth),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
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
          ),
        ),
      );
    },
  );
}
