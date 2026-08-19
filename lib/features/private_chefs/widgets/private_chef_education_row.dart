import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/private_chef_education.dart';

/// One education item in Chef Detail's BACKGROUND section — institution
/// primary, program secondary, optional period. Deliberately never
/// tappable (no canonical "institution" domain exists or is planned —
/// see the education migration's own header comment) and deliberately
/// carries no recognition/stars of any kind, unlike the restaurant
/// variant of a Background item ([PrivateChefProvenanceRow]).
class PrivateChefEducationRow extends StatelessWidget {
  final PrivateChefEducation education;

  const PrivateChefEducationRow({super.key, required this.education});

  @override
  Widget build(BuildContext context) {
    final period = (education.periodText ?? '').trim();
    final hasPeriod = period.isNotEmpty;

    final semanticLabel = [
      education.institution,
      education.program,
      if (hasPeriod) period,
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              education.institution,
              style: CsTypography.placeTitle.copyWith(
                fontSize: 17,
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              education.program,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            if (hasPeriod) ...[
              const SizedBox(height: 2),
              Text(
                period,
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
