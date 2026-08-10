import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// The elegant circular score treatment: a thin progress ring around a
/// serif numeral, with a small caption beneath — replaces the heavier
/// 10-segment bar-meter presentation for at-a-glance personal/latest-visit
/// scores on Restaurant/Hotel Detail. [score] and [maxScore] share a scale
/// (visits/stays are rated out of 10 throughout the app). The ring reads
/// in brand green, not gold — this is the guest's own rating, not a
/// Michelin/World's 50 Best award, and gold stays reserved for those.
class CircularScoreBadge extends StatelessWidget {
  final int? score;
  final int maxScore;
  final String caption;
  final double diameter;

  const CircularScoreBadge({
    super.key,
    required this.score,
    required this.caption,
    this.maxScore = 10,
    this.diameter = 68,
  });

  @override
  Widget build(BuildContext context) {
    final value = score;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value == null ? 0 : value / maxScore,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.brandGreen,
                  ),
                ),
              ),
              Text(
                value == null ? '—' : '$value',
                style: AppTypography.score.copyWith(fontSize: diameter * 0.32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppTypography.metadata,
        ),
      ],
    );
  }
}
