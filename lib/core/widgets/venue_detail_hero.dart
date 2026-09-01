import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';
import 'editorial_back_button.dart';
import 'follow_toggle_button.dart';

/// The current-generation hero for Restaurant/Hotel Detail (UI Consistency
/// Step 1) — a fresh, Cs-token-based primitive, deliberately NOT a
/// modification of [DetailHero] (`detail_hero.dart`), which stays exactly
/// as it is: that widget is shared with Event Detail, both Award History
/// screens, and other screens explicitly out of scope for this redesign,
/// and editing it would risk changing their appearance too. This is a
/// parallel component for the two screens that are actually being
/// redesigned, following the exact same "one small primitive genuinely
/// reused twice" reasoning as everywhere else in this pass.
///
/// No catalogue table carries a restaurant/hotel photo today — same as
/// [DetailHero] — so [backgroundImage] stays optional and unused at every
/// current call site. The no-photo state is a considered deep-green tonal
/// gradient, not a placeholder pretending to be a photo; passing a real
/// image widget later is the only change needed to light up real
/// photography, since the scrim/legibility treatment already accounts for
/// one being there.
class VenueDetailHero extends StatelessWidget {
  final String title;

  /// The single primary recognition signal (Michelin stars for a
  /// restaurant, Keys for a hotel) — rendered large and alone, never
  /// competing with secondary badges. Omit entirely (pass null) rather
  /// than an empty row when there is no current recognition to show.
  final Widget? primaryRecognition;

  /// Secondary context chips — "World's 50 Best · #12", "Inside Aman
  /// Venice" — visually quieter than [primaryRecognition] by design.
  final List<Widget> secondaryBadges;

  final double expandedHeight;
  final Widget? backgroundImage;

  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  /// Events V2 Step 6. [onTapFollow] is deliberately nullable and defaults
  /// to null — when omitted, no Follow control renders at all, so every
  /// existing call site (and every existing test) that predates Follow
  /// keeps its exact prior rendering with zero changes required. Only
  /// Restaurant/Hotel Detail (the two screens that wire a real callback)
  /// show the second hero icon.
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onTapFollow;

  const VenueDetailHero({
    super.key,
    required this.title,
    this.primaryRecognition,
    this.secondaryBadges = const [],
    // Generous enough for the realistic worst case — a long, wrapped
    // 2-line title alongside 3-star/3-Key primary recognition and two
    // wrapped secondary badges — to fit without clipping even at 1.6x
    // text scale (§18). The SingleChildScrollView below is a defensive
    // second layer, not the primary fix: it guarantees no RenderFlex
    // overflow ever throws, but sizing this generously means it's never
    // actually needed for realistic content.
    this.expandedHeight = 300,
    this.backgroundImage,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
    this.isFollowing = false,
    this.followBusy = false,
    this.onTapFollow,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = backgroundImage != null;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: CsSpacing.sm),
        child: EditorialBackButton(),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: CsSpacing.sm),
          child: _HeroToggleButton(
            icon: isWishlisted
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            active: isWishlisted,
            onTap: wishlistSaving ? null : onTapWishlist,
          ),
        ),
        if (onTapFollow != null)
          Padding(
            padding: const EdgeInsets.only(right: CsSpacing.sm),
            child: FollowToggleButton(
              isFollowing: isFollowing,
              busy: followBusy,
              onTap: onTapFollow,
              entityName: title,
            ),
          ),
      ],
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              backgroundImage!
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandGreenLight,
                      AppColors.deepGreen,
                      AppColors.heroGradientEnd,
                    ],
                  ),
                ),
              ),
            // Bottom-weighted vignette so the title/badges stay legible
            // regardless of whether there's a photo underneath.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.55 : 0),
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.9 : 1),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.hero,
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                ),
                // A defensive second layer against overflow, not the
                // primary fix (see [expandedHeight]'s doc comment): giving
                // the column unconstrained height means even a pathological
                // combination of a very long title and several long badge
                // labels clips gracefully at the bottom rather than
                // throwing a RenderFlex overflow error.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (primaryRecognition != null) ...[
                        primaryRecognition!,
                        const SizedBox(height: CsSpacing.sm),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.displayHero.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 30,
                          height: 1.1,
                        ),
                      ),
                      if (secondaryBadges.isNotEmpty) ...[
                        const SizedBox(height: CsSpacing.sm),
                        Wrap(
                          spacing: CsSpacing.sm,
                          runSpacing: CsSpacing.sm,
                          children: secondaryBadges,
                        ),
                      ],
                    ],
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

/// The overlay wishlist toggle — same "translucent disc over the hero"
/// visual idea the previous generation used, rebuilt as independent code
/// rather than reusing `HeroIconButton` from `detail_hero.dart` (kept
/// fully untouched — see this file's own class doc).
class _HeroToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _HeroToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.24),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(
          icon,
          // Step 1B color rule: gold is reserved for Michelin stars/Keys
          // only. Wishlist state reads through the filled-vs-outline icon
          // shape alone (favorite_rounded vs favorite_border_rounded), not
          // color — both states stay ivory-on-dark.
          color: AppColors.textOnDark,
          size: 19,
        ),
      ),
    ),
  );
}

/// A small translucent secondary badge for hero-overlaid context —
/// "World's 50 Best · #12", "Inside Aman Venice". The Cs-token twin of
/// `HeroBadge` (`detail_hero.dart`), rebuilt independently for the same
/// "don't touch the shared component" reason as the rest of this file.
class VenueHeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const VenueHeroBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(CsRadius.pill),
      border: Border.all(
        color: AppColors.textOnDark.withValues(alpha: 0.25),
        width: 0.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textOnDark),
        const SizedBox(width: 5),
        Text(
          label,
          style: CsTypography.smallLabel.copyWith(color: AppColors.textOnDark),
        ),
      ],
    ),
  );
}
