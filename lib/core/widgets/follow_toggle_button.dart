import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// The Follow toggle, shared across Restaurant Detail, Hotel Detail and
/// Private Chef Detail (via [VenueDetailHero]'s hero actions and
/// [PrivateChefHero]'s own hero respectively). Deliberately its own
/// widget, not a reuse of the hero's Wishlist heart: the two concepts get
/// their own small components rather than one toggle serving two
/// meanings.
///
/// A labelled pill, not an icon (revised 2026-10-30). The earlier
/// person-add glyph changed only from outline to filled, which on a
/// photo at 19pt read as no change at all, so people could not tell
/// whether they followed a venue. Now the state is spelled out and the
/// shape changes with it:
///
/// - not following: a translucent pill with a thin ivory outline, "+"
///   and "Follow";
/// - following: a solid ivory pill, forest-green check and "Following".
///
/// Never gold (reserved for MICHELIN stars and Keys), never a heart
/// (Wishlist), a bookmark (Event Interested) or a bell (it is not a
/// notification setting).
///
/// The screens update optimistically: [isFollowing] flips the moment the
/// pill is tapped and flips back if the write fails. [busy] covers the
/// write in flight; it only ignores taps, so a second tap can never race
/// the first, and shows no spinner — the state already reads as done.
class FollowToggleButton extends StatelessWidget {
  final bool isFollowing;
  final bool busy;
  final VoidCallback? onTap;

  /// The followed entity's own display name — used only for the
  /// accessibility label ("Unfollow Parkheuvel"), so a screen-reader user
  /// knows which of the hero's controls this is.
  final String entityName;

  const FollowToggleButton({
    super.key,
    required this.isFollowing,
    required this.busy,
    required this.onTap,
    required this.entityName,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isFollowing
        ? AppColors.forestGreen
        : AppColors.textOnDark;
    return Semantics(
      button: true,
      selected: isFollowing,
      label: isFollowing
          ? 'Following $entityName. Tap to unfollow'
          : 'Follow $entityName',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: ShapeDecoration(
          color: isFollowing
              ? AppColors.ivory
              : Colors.black.withValues(alpha: 0.24),
          shape: StadiumBorder(
            side: BorderSide(
              color: isFollowing
                  ? AppColors.ivory
                  : AppColors.textOnDark.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing ? Icons.check_rounded : Icons.add_rounded,
                    color: foreground,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: CsTypography.metadata.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
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
