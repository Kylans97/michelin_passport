import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';

/// The shared shell every Guide catalogue screen sits on top of —
/// deliberately presentation-only. It knows a catalogue has a source
/// family, a title, an optional supporting line, and an optional content
/// slot below — nothing about stars, Keys, rank, restaurant/hotel models,
/// filters, years or repositories. Michelin Restaurants/Hotels and 50
/// Best Restaurants/Hotels (Step 2B/2C) each supply their own [content]
/// (search field, filters, result list) later; this shell never needs to
/// change to accommodate that, since it only ever renders whatever widget
/// it's handed.
///
/// A real [Scaffold] (not a bare canvas) — this is pushed via
/// [MaterialPageRoute] from [GuidesScreen], which has no enclosing
/// Scaffold of its own to inherit (same reasoning as LoginScreen/
/// SignupScreen in Step 4A). The back affordance is a small
/// [EditorialBackButton] — fixed inside the header rather than floating
/// over it — never a default Material AppBar; a plain [MaterialPageRoute]
/// push/pop keeps iOS edge-swipe-to-pop working with no extra wiring.
///
/// Step 1B — CATALOGUE HEADER: the header is now a fixed forest-green
/// editorial masthead — [source] (the Guide family, e.g. "MICHELIN
/// GUIDE") prominent in ivory, [title] (the content type, "Restaurants"/
/// "Hotels") smaller and subordinate in [AppColors.secondaryOnDark] —
/// deliberately the exact same size relationship [GuidesScreen]'s own
/// family-title-vs-destination-label hierarchy already uses, so a
/// catalogue page visually continues the landing page rather than
/// introducing a second hierarchy language. Below it, [content] (search,
/// filters, results) sits on an explicitly ivory-painted area — the
/// forest-green-to-ivory color transition itself is now the separator
/// between them; no hairline is inserted there, since a hand-drawn line
/// would be redundant next to a full color-block boundary already this
/// strong (contrast with [GuideVenueCardDivider], still used between
/// individual venue rows inside [content] — a genuinely different, much
/// lower-contrast context that still needs a drawn line).
///
/// UI Polish pass: [Scaffold.backgroundColor] is forest-green (not ivory)
/// and the header sits in a `SafeArea(bottom: false)` rather than the
/// header+content sharing one `SafeArea` — physical-device review found
/// the previous ivory-Scaffold version left an unintended ivory strip
/// behind the iOS status bar, above the green masthead, because the safe-
/// area top inset was rendered against the Scaffold's own (then-ivory)
/// background before the masthead's [ColoredBox] ever got a chance to
/// paint it. Forest-green is now the Scaffold's background precisely so
/// that gap reads as a seamless continuation of the masthead instead; the
/// content area below now paints its own explicit ivory [ColoredBox] (it
/// used to rely on the Scaffold's background showing through) so it stays
/// ivory regardless of what the Scaffold itself is set to, with its own
/// `SafeArea(top: false)` for the bottom inset so no green ever leaks in
/// behind the home indicator. [AnnotatedRegion] forces light (ivory)
/// status-bar icons for exactly this screen — neither of the app's two
/// themes currently applies that automatically here, since this shell has
/// no [AppBar]/[SliverAppBar] for a theme's `appBarTheme.
/// systemOverlayStyle` to attach to.
///
/// Green Token Consistency Migration: the masthead is AppColors.deepGreen,
/// not forestGreen — the canonical primary brand dark surface, matching
/// Explore/Passport/Event Detail's hero and every other migrated masthead
/// (Wishlist, Friends, this screen's own siblings).
class GuideCatalogueLayout extends StatelessWidget {
  /// The Guide family, e.g. "MICHELIN GUIDE" or "THE WORLD'S 50 BEST" —
  /// the header's prominent line.
  final String source;

  /// The catalogue's own content type, e.g. "Restaurants" or "Hotels" —
  /// the header's subordinate line.
  final String title;

  /// A short, truthful supporting line. Optional — omit rather than pad
  /// with copy that doesn't earn its place.
  final String? subtitle;

  /// Where Step 2B/2C's search/filter/result-list content goes. Deliberately
  /// null for the still-frozen Step 2A shells: no fake venues, no
  /// placeholder list — the composition simply ends after the header for
  /// those. When supplied, expected to manage its own internal scrolling
  /// (see the class doc above).
  final Widget? content;

  const GuideCatalogueLayout({
    super.key,
    required this.source,
    required this.title,
    this.subtitle,
    this.content,
  });

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        source,
        style: CsTypography.sectionTitle.copyWith(color: AppColors.ivory),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: CsTypography.placeTitle.copyWith(
          color: AppColors.secondaryOnDark,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: CsSpacing.sm),
        Text(
          subtitle!,
          style: CsTypography.metadata.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ColoredBox(
              color: AppColors.deepGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.base,
                      CsSpacing.xs,
                      CsSpacing.base,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: EditorialBackButton(color: AppColors.ivory),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.sm,
                      CsSpacing.pageHorizontal,
                      CsSpacing.xl,
                    ),
                    child: _header(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.ivory,
              child: SafeArea(
                top: false,
                child: content == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: CsSpacing.lg),
                        child: content!,
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
