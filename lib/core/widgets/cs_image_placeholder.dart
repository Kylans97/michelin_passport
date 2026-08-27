import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';

/// The official Mantelier monogram assets — SVGs from the Mantelier asset
/// kit, used exactly as provided (see assets/branding/ — never redrawn,
/// retraced or reinterpreted), text already outlined to paths (no font
/// dependency). [CsImagePlaceholder] is the only place
/// [csMonogramSmallAssetPath] should appear — it picks between the two
/// based on rendered size; every other call site should reference
/// [csMonogramAssetPath] directly only when it always renders at 40px or
/// larger (see [AuthBrandHeader], [AuthGate]'s splash), so there is one
/// place to change if the master asset is ever replaced.
///
/// The ivory-ink variant (transparent ground) — not mark-green-ink.svg —
/// because every current consumer of this constant renders on a dark
/// (deep-green) surface: [CsImagePlaceholder]'s own [AppColors.brandGreen]
/// background, and the deep-green auth canvas behind [AuthBrandHeader]/
/// the splash screen.
const String csMonogramAssetPath = 'assets/branding/mark-ivory-ink.svg';

/// The small-format companion to [csMonogramAssetPath] — no hem stroke,
/// since that detail aliases away below ~40 logical px anyway. Used only
/// by [CsImagePlaceholder], which switches to this automatically once its
/// computed monogram size drops under that threshold (e.g. the Community
/// list's small event thumbnails).
const String csMonogramSmallAssetPath =
    'assets/branding/mark-small-ivory-ink.svg';

/// Below this rendered monogram size (logical px), [CsImagePlaceholder]
/// switches from [csMonogramAssetPath] to [csMonogramSmallAssetPath].
const double _csMonogramSmallThreshold = 40;

/// The standard branded fallback wherever Mantelier doesn't yet have an
/// official photo for a restaurant, hotel or event: a deep forest-green
/// field with the official Mantelier monogram centered. The monogram is
/// rendered exactly as exported in the source SVG — no color filter, no
/// recoloring — its baked-in ink is already the same warm-ivory family as
/// [AppColors.textOnDark]; deliberately not forced to match that token
/// pixel-for-pixel, since doing so would mean repainting every pixel of
/// the approved artwork rather than displaying it as provided. No text, no
/// star, no gold, no generic broken-image icon — a calm, understated
/// placeholder that never looks like an empty slot.
///
/// Sizes itself to whatever constraints it's given (explicit [width]/
/// [height], or the parent's own constraints when both are omitted — e.g.
/// inside a [Stack] with `fit: StackFit.expand`, as [DetailHero] uses it),
/// so the same widget covers small thumbnails, normal cards and large hero
/// areas. The monogram is sized as a fraction of the SHORTEST rendered
/// dimension ([logoScale], default 0.25 — the mark's own SVG viewBox
/// already carries generous internal padding around the ink, unlike the
/// old filled-square asset this replaced, so a smaller fraction of the box
/// reads as the same visual weight); pass a smaller value still for large
/// hero placeholders (see [EventDetailScreen]'s use, ~0.22) so the mark
/// doesn't dominate.
///
/// Below [_csMonogramSmallThreshold] logical px, this switches from
/// [csMonogramAssetPath] to [csMonogramSmallAssetPath] — the hemless
/// variant, since the hem stroke aliases away at that size regardless.
///
/// A vector asset ([SvgPicture.asset]) — unlike the source PNG this
/// replaced, there's no raster decode-size tradeoff to manage
/// (`cacheWidth`/`cacheHeight` was PNG-specific and no longer applies):
/// the SVG renders crisply at whatever [logoSize] this widget computes,
/// from a small list-item thumbnail up to a large hero placeholder, with
/// no resolution loss and no oversized-source-decode cost either.
class CsImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double logoScale;

  const CsImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.logoScale = 0.25,
  });

  // Used when the actual layout constraints are unbounded in a dimension
  // (e.g. this widget dropped into an unconstrained Column) — a sensible
  // fixed logo size rather than an unbounded/zero computation.
  static const double _fallbackLogoSize = 64;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.brandGreen),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortestSide = _shortestFiniteSide(constraints);
              final logoSize = shortestSide != null
                  ? shortestSide * logoScale
                  : _fallbackLogoSize;

              // Vector asset — no cacheWidth/cacheHeight raster-decode
              // sizing needed (that was PNG-specific); SvgPicture renders
              // at whatever size it's given with no resolution loss.
              final assetPath = logoSize < _csMonogramSmallThreshold
                  ? csMonogramSmallAssetPath
                  : csMonogramAssetPath;
              return Center(
                child: SvgPicture.asset(
                  assetPath,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double? _shortestFiniteSide(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final finiteW = w.isFinite ? w : null;
    final finiteH = h.isFinite ? h : null;
    if (finiteW == null && finiteH == null) return null;
    if (finiteW == null) return finiteH;
    if (finiteH == null) return finiteW;
    return finiteW < finiteH ? finiteW : finiteH;
  }
}
