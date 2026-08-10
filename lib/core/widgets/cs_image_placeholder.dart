import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The single official Chasing Stars monogram asset — a transparent PNG,
/// used exactly as provided (see assets/branding/ — never redrawn,
/// retraced or reinterpreted). [CsImagePlaceholder] is the only place this
/// path should appear; every other call site should go through that widget
/// rather than referencing the asset directly, so there is one place to
/// change if the master asset is ever replaced.
const String csMonogramAssetPath = 'assets/branding/chasing_stars_monogram.png';

/// The standard branded fallback wherever Chasing Stars doesn't yet have an
/// official photo for a restaurant, hotel or event: a deep forest-green
/// field with the official CS monogram centered. The monogram is rendered
/// exactly as exported in the source PNG — no color filter, no
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
/// dimension ([logoScale], default 0.4 — within the brief's 35–45% range
/// for normal cards); pass a smaller value for large hero placeholders
/// (see [EventDetailScreen]'s use, ~0.22) so the mark doesn't dominate.
///
/// Decodes the source PNG at roughly the size it's actually displayed
/// (via `cacheWidth`/`cacheHeight`, scaled by the device's pixel ratio)
/// rather than the full ~3246×4096 source for every list-item thumbnail —
/// same intent as [Image.network]'s `cacheWidth` elsewhere in the app, just
/// for an asset instead of a network image.
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
    this.logoScale = 0.4,
  });

  // Used when the actual layout constraints are unbounded in a dimension
  // (e.g. this widget dropped into an unconstrained Column) — a sensible
  // fixed logo size rather than an unbounded/zero computation.
  static const double _fallbackLogoSize = 64;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

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
              final cacheDimension = (logoSize * devicePixelRatio)
                  .clamp(1, 1024)
                  .round();

              return Center(
                child: Image.asset(
                  csMonogramAssetPath,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  cacheWidth: cacheDimension,
                  cacheHeight: cacheDimension,
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
