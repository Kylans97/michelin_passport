import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// The shared hero chrome for Restaurant/Hotel Detail — the SINGLE primary
/// identity area for a venue: name, award badge and overlay navigation.
/// Nothing below the hero repeats the venue name; once this collapses to
/// its pinned title, that title (not a second heading in the content
/// area) is the only name shown.
///
/// No catalogue table carries a venue image today, so [backgroundImage] is
/// null for every current call site and the hero renders a considered
/// brand-green tone instead of a photo. Passing a real image widget later
/// (e.g. `Image.network(...)`) is the only change needed to light up real
/// photography — the scrim, text legibility and layout beneath it already
/// account for a photo being there.
class DetailHero extends StatelessWidget {
  final String title;
  final Widget awardBadge;
  final List<Widget> extraBadges;
  final double expandedHeight;
  final Widget? backgroundImage;

  // Rendered as an overlay action on the hero itself (e.g. wishlist) —
  // optional, since not every detail screen has a personal-state toggle
  // worth surfacing this prominently yet.
  final Widget? overlayAction;

  const DetailHero({
    super.key,
    required this.title,
    required this.awardBadge,
    this.extraBadges = const [],
    this.expandedHeight = 208,
    this.backgroundImage,
    this.overlayAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = backgroundImage != null;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.brandGreen,
      foregroundColor: AppColors.textOnDark,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: HeroIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      actions: overlayAction == null
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: overlayAction,
              ),
            ],
      title: Text(
        title,
        style: AppTypography.editorialHeading.copyWith(
          color: AppColors.textOnDark,
          fontSize: 16,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto) backgroundImage!,
            // With a photo, this is a bottom-weighted vignette so the image
            // reads clearly at the top and text stays legible at the
            // bottom. Without one (every venue today) it's the full brand
            // tone standing in for photography — see class doc.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hasPhoto
                      ? [
                          Colors.transparent,
                          AppColors.brandGreen.withValues(alpha: 0.55),
                          AppColors.brandGreen.withValues(alpha: 0.92),
                        ]
                      : const [
                          AppColors.brandGreenLight,
                          AppColors.brandGreen,
                          Color(0xFF0E211C),
                        ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 44, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    awardBadge,
                    if (extraBadges.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: extraBadges),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: AppTypography.display.copyWith(
                        color: AppColors.textOnDark,
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small circular overlay button — the "navigation/actions without
/// obscuring the image" treatment: a translucent dark disc so it stays
/// legible over the hero regardless of what's behind it.
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.24),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color ?? AppColors.textOnDark, size: 18),
      ),
    ),
  );
}

/// A small translucent badge for hero-overlaid context (award/rank
/// callouts, "inside X Hotel" etc.) — legible over the brand-green hero
/// regardless of gradient position.
class HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const HeroBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
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
          style: AppTypography.label.copyWith(
            color: AppColors.textOnDark,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}
