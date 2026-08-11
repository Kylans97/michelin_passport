import 'package:flutter/material.dart';
import '../theme/cs_typography.dart';

/// The redesigned section heading — [CsTypography.sectionTitle] (Cormorant
/// Garamond) — the Step 1 counterpart to [EditorialHeading]/[SectionLabel]
/// in `detail_card.dart`, which keep using [AppTypography] unchanged. Not
/// wired into any screen yet; text-only, no layout/context assumptions, so
/// it's safe to introduce now and adopt later.
class CsSectionTitle extends StatelessWidget {
  final String text;
  final Color? color;

  /// Both default to null/unbounded, preserving the original behavior
  /// (wraps freely, no truncation) for any existing call site that doesn't
  /// pass them. Pass both together (e.g. `maxLines: 1, overflow:
  /// TextOverflow.ellipsis`) when this title shares a Row with other
  /// content and needs to yield space rather than force an overflow.
  final int? maxLines;
  final TextOverflow? overflow;

  const CsSectionTitle(
    this.text, {
    super.key,
    this.color,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: overflow,
    style: color == null
        ? CsTypography.sectionTitle
        : CsTypography.sectionTitle.copyWith(color: color),
  );
}
