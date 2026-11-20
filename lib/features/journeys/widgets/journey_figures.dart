import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../journey_visuals.dart';

/// A quiet row of serif figures between two hairlines: "2 Nights",
/// "35 Cabins". Only what the journey states (see [journeyFigures]).
class JourneyFigures extends StatelessWidget {
  final List<JourneyFigure> figures;

  const JourneyFigures({super.key, required this.figures});

  @override
  Widget build(BuildContext context) {
    const rule = BorderSide(color: AppColors.subtleBorderLight);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: rule, bottom: rule),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < figures.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.subtleBorderLight,
                ),
              Expanded(child: _Figure(figure: figures[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final JourneyFigure figure;

  const _Figure({required this.figure});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.base),
    child: Column(
      children: [
        Text(
          figure.value,
          style: CsTypography.stampStatValue.copyWith(
            color: AppColors.forestGreen,
          ),
        ),
        const SizedBox(height: CsSpacing.xs),
        Text(
          figure.label.toUpperCase(),
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
      ],
    ),
  );
}
