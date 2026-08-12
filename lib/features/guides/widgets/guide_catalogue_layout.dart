import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';

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
/// SignupScreen in Step 4A). The back affordance is a small
/// [EditorialBackButton] — fixed above the header rather than floating
/// over it — never a default Material AppBar; a plain [MaterialPageRoute]
/// push/pop keeps iOS edge-swipe-to-pop working with no extra wiring.
///
/// Step 2B addition: when [content] is supplied, the header stops being
/// part of the scroll view and becomes a fixed block, with [content] given
/// the remaining height via [Expanded] instead. This is the shell's one
/// permitted small additive change — Michelin Restaurants/Hotels' own
/// result list is a [ListView] that needs to own scrolling itself (so a
/// catalogue of hundreds of places is lazily built, not eagerly laid out
/// in a single giant [Column]); nesting that inside the header's own
/// [SingleChildScrollView], as a naive content slot would, produces two
/// competing scrollables. Screens that pass no [content] (Step 2A's four
/// shells, and 50 Best's still-frozen pair) are completely unaffected —
/// they keep the exact original header-only [SingleChildScrollView], so a
/// short/likely-not-full-height header never looks like a broken half-
/// empty scrollable.
class GuideCatalogueLayout extends StatelessWidget {
  /// The eyebrow-weight source line, e.g. "MICHELIN GUIDE" or
  /// "THE WORLD'S 50 BEST".
  final String source;

  /// The catalogue's own title, e.g. "Restaurants" or "Hotels".
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
        style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
      ),
      const SizedBox(height: CsSpacing.xs),
      Text(
        title,
        style: CsTypography.screenTitle.copyWith(color: AppColors.textOnDark),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: CsSpacing.sm),
        Text(
          subtitle!,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final body = content == null
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.hero,
              CsSpacing.pageHorizontal,
              CsSpacing.xxl,
            ),
            child: _header(),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.hero,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: _header(),
              ),
              const SizedBox(height: CsSpacing.section),
              Expanded(child: content!),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
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
                child: EditorialBackButton(),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
