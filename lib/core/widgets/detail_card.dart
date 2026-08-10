import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Small uppercase eyebrow label used above a dense section of a detail
/// screen ("INFORMATION", "ACTIONS", "AWARDS"). For a warmer, more
/// editorial section title, see [EditorialHeading].
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.sectionHeading);
}

/// A prominent serif section heading with editorial warmth — used where a
/// section deserves more presence than [SectionLabel]'s compact eyebrow
/// text (e.g. Award History's "Michelin History" / "World's 50 Best").
class EditorialHeading extends StatelessWidget {
  final String text;
  const EditorialHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.editorialHeading);
}

/// The soft, rounded card shell reused across every detail screen's
/// sections — warm surface fill and a whisper-light hairline, deliberately
/// lighter than a typical "boxed" UI card so it reads as a gentle content
/// grouping rather than a bordered database-row container.
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(
        color: AppColors.cardBorder.withValues(alpha: 0.55),
        width: 0.5,
      ),
    ),
    child: child,
  );
}
