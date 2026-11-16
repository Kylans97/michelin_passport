import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/guide_award.dart';

/// One shared-table guide on Award History (a regional 50 Best list): every
/// edition this restaurant appears in, newest first, then the guide's own
/// coverage note for its latest edition — what we hold, said plainly, as
/// the Gault&Millau guide page does. Ivory on green, never gold.
class GuideAwardHistorySection extends StatelessWidget {
  /// One guide's rows, newest edition first.
  final List<GuideAward> awards;
  final GuideCoverage? coverage;

  const GuideAwardHistorySection({
    super.key,
    required this.awards,
    this.coverage,
  });

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          awards.first.guideName.toUpperCase(),
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < awards.length; i++) ...[
          _EditionRow(award: awards[i]),
          if (i != awards.length - 1) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.subtleBorderDark, height: 1),
            const SizedBox(height: 10),
          ],
        ],
        if (coverage != null) ...[
          const SizedBox(height: CsSpacing.md),
          Text(
            '${coverage!.editionYear} edition: ${coverage!.note}',
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ],
    );
  }
}

class _EditionRow extends StatelessWidget {
  final GuideAward award;
  const _EditionRow({required this.award});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '${award.editionYear}',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      Text(
        formatGuideAwardValue(award) ?? 'Listed',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
