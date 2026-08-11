import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/detail_hero.dart' show HeroIconButton;

/// The shared shell every Guide catalogue screen sits on top of —
/// deliberately presentation-only. It knows a catalogue has a source
/// family (eyebrow), a title, an optional supporting line, and an
/// optional content slot below — nothing about stars, Keys, rank,
/// restaurant/hotel models, filters, years or repositories. Michelin
/// Restaurants/Hotels and 50 Best Restaurants/Hotels (Step 2B/2C) each
/// supply their own [content] (search field, filters, result list) later;
/// this shell never needs to change to accommodate that, since it only
/// ever renders whatever widget it's handed.
///
/// A real [Scaffold] (not a bare canvas) — this is pushed via
/// [MaterialPageRoute] from [GuidesScreen], which has no enclosing
/// Scaffold of its own to inherit (same reasoning as LoginScreen/
/// SignupScreen in Step 4A). The back affordance reuses [HeroIconButton]
/// verbatim — the same translucent-circle treatment already established
/// by DetailHero and Sign up's back button — rather than a default
/// Material AppBar, and a plain [MaterialPageRoute] push/pop keeps iOS
/// edge-swipe-to-pop working with no extra wiring.
class GuideCatalogueLayout extends StatelessWidget {
  /// The eyebrow-weight source line, e.g. "MICHELIN GUIDE" or
  /// "THE WORLD'S 50 BEST".
  final String source;

  /// The catalogue's own title, e.g. "Restaurants" or "Hotels".
  final String title;

  /// A short, truthful supporting line. Optional — omit rather than pad
  /// with copy that doesn't earn its place.
  final String? subtitle;

  /// Where Step 2B/2C's search/filter/result-list content will go.
  /// Deliberately null in Step 2A: no fake venues, no placeholder list —
  /// the composition simply ends after the header for this pass.
  final Widget? content;

  const GuideCatalogueLayout({
    super.key,
    required this.source,
    required this.title,
    this.subtitle,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.hero,
                CsSpacing.pageHorizontal,
                CsSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source,
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    title,
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: CsSpacing.sm),
                    Text(
                      subtitle!,
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                  if (content != null) ...[
                    const SizedBox(height: CsSpacing.section),
                    content!,
                  ],
                ],
              ),
            ),
            Positioned(
              left: CsSpacing.base,
              top: CsSpacing.sm,
              child: HeroIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
