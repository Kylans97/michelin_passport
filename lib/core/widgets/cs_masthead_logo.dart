import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'cs_image_placeholder.dart' show csMonogramAssetPath, csMonogramSmallAssetPath;

/// The one official Mantelier monogram asset ([CsImagePlaceholder]'s own
/// SVGs — never redrawn), just sized for the two spots this pass uses it
/// standalone rather than as an image fallback: a small masthead mark in
/// a screen header, and a large mark on the Passport-cover alternative.
/// Picks the hemless small-format SVG below 40px, exactly matching
/// [CsImagePlaceholder]'s own threshold, for the same reason (the hem
/// stroke aliases away at that size regardless).
class CsMastheadLogo extends StatelessWidget {
  final double size;

  const CsMastheadLogo({super.key, this.size = 22});
  const CsMastheadLogo.cover({super.key}) : size = 76;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    size < 40 ? csMonogramSmallAssetPath : csMonogramAssetPath,
    width: size,
    height: size,
  );
}
