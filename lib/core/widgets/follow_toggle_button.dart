import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Events V2 Step 6 — the Follow toggle, shared across Restaurant Detail,
/// Hotel Detail, and Private Chef Detail (via [VenueDetailHero]'s hero
/// actions and [PrivateChefHero]'s own hero respectively). Deliberately a
/// standalone widget, not a reuse of [VenueDetailHero]'s private Wishlist
/// toggle — Wishlist's own rendering path stays byte-for-byte untouched by
/// this step (Follow Audit's own explicit instruction), and the two
/// concepts get their own independent, small components rather than one
/// shared toggle secretly serving two different meanings.
///
/// Icon family — Events V2 Step 6 UX correction, physical-device review:
/// the original bell ([Icons.notifications_none_rounded]/
/// [Icons.notifications_rounded]) read primarily as "notifications" on
/// device, not "Follow". Replaced with a person-add pair
/// ([Icons.person_add_alt_1_outlined]/[Icons.person_add_alt_1_rounded]) —
/// the same glyph, outline vs. filled, reading as "add this place/person
/// to your following" without any notification connotation. Still
/// deliberately NOT a heart (Wishlist's own icon in this exact hero), NOT
/// a bookmark (Event Interested's icon on Event Detail), and NOT a star
/// (reserved for Michelin recognition elsewhere in this product) — no
/// gold, no external icon package.
///
/// Same visual family as the hero's translucent-circle Wishlist toggle
/// (deepGreen/ivory hero, [AppColors.textOnDark] icon, filled vs. outline
/// for state — never color alone, never gold) — a small spinner replaces
/// the icon while [busy], and the whole control becomes non-interactive
/// during that window to prevent a second tap racing the first, mirroring
/// EventIntentControls' own busy/spinner convention.
class FollowToggleButton extends StatelessWidget {
  final bool isFollowing;
  final bool busy;
  final VoidCallback? onTap;

  /// The followed entity's own display name — used only to build a
  /// specific accessibility label ("Follow Parkheuvel", never a bare
  /// "Follow" that leaves a screen-reader user guessing which of several
  /// hero icons this is). Never rendered as visible text on the control
  /// itself, which stays icon-only by design.
  final String entityName;

  const FollowToggleButton({
    super.key,
    required this.isFollowing,
    required this.busy,
    required this.onTap,
    required this.entityName,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isFollowing,
    label: isFollowing ? 'Unfollow $entityName' : 'Follow $entityName',
    child: Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: busy
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textOnDark,
                  ),
                )
              : Icon(
                  isFollowing
                      ? Icons.person_add_alt_1_rounded
                      : Icons.person_add_alt_1_outlined,
                  color: AppColors.textOnDark,
                  size: 19,
                ),
        ),
      ),
    ),
  );
}
