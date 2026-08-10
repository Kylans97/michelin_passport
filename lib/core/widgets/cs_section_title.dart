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

  const CsSectionTitle(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: color == null
        ? CsTypography.sectionTitle
        : CsTypography.sectionTitle.copyWith(color: color),
  );
}
