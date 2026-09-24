import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// The magazine pass's photo-fallback: a typographic tile, not the "M"
/// monogram [CsImagePlaceholder] shows. A green-800 field, a 1px accent-700
/// border, the venue's own initials in Cormorant italic gold-300, and an
/// optional type label beneath — every visited/discoverable place reads as
/// itself even without a photo, rather than falling back to the brand
/// mark. Corners max 2pt (this pass replaces rounded cards with hairlines
/// and near-square edges throughout).
///
/// Deliberately a NEW, separate widget rather than changing
/// [CsImagePlaceholder] in place: this redesign is being rolled out screen
/// by screen (see the pass's own "Werkwijze"), and [CsImagePlaceholder] is
/// still the active fallback on every screen not yet migrated — mutating
/// it here would reskin all of them as an unintended side effect of this
/// one screen's work. Screens migrate onto this widget deliberately, the
/// same additive pattern [CsSpacing]/[CsTypography] themselves already
/// established relative to their own pre-redesign equivalents.
class CsEditorialImageFallback extends StatelessWidget {
  final String venueName;
  final String? typeLabel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const CsEditorialImageFallback({
    super.key,
    required this.venueName,
    this.typeLabel,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
  });

  String get _initials {
    final words = venueName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    // Prefer words that actually START with a letter — confirmed via
    // this pass's own visual QA that a name like "8½ Otto e Mezzo
    // Bombana" produced "8O" (word[0][0]='8', word[1][0]='O'), which
    // reads as "80" at a glance rather than two initials. Falls back to
    // the literal first word(s) only if nothing in the name starts with
    // a letter at all (e.g. a name that's entirely numerals/symbols).
    final letterWords = words
        .where((w) => RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(w))
        .toList();
    final source = letterWords.length >= 2
        ? letterWords
        : (letterWords.length == 1 ? [...letterWords, ...words] : words);
    if (source.length == 1) {
      return source.first.substring(0, source.first.length.clamp(0, 2)).toUpperCase();
    }
    return (source[0][0] + source[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.green800,
        border: Border.all(color: AppColors.accent700, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortestSide = _shortestFiniteSide(constraints) ?? 64;
          final initialsSize = (shortestSide * 0.34).clamp(14.0, 40.0);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _initials,
                  style: CsTypography.editorialTitle(
                    size: initialsSize,
                    italic: true,
                  ).copyWith(color: AppColors.gold300),
                ),
                if (typeLabel != null && typeLabel!.isNotEmpty && shortestSide > 56) ...[
                  const SizedBox(height: 4),
                  Text(
                    typeLabel!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.editorialLabel(size: 9).copyWith(
                      color: AppColors.gold300,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );

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
