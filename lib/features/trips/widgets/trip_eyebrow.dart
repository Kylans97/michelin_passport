import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';

/// A small uppercase section label for Trips' dark editorial screens — the
/// same eyebrow treatment [GuideCatalogueLayout] uses for its own source
/// line, reused here since Trips' [SectionLabel] equivalent (core/widgets/
/// detail_card.dart) is styled for the light-card system and stays
/// untouched for its many other (non-Trips) callers.
class TripSectionLabel extends StatelessWidget {
  final String text;
  const TripSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
  );
}
