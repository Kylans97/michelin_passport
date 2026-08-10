import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/award_transition.dart';

/// A calm, vertical timeline of award transitions: year on the left, a thin
/// connecting line, a badge and the transition copy on the right. Built
/// generic over [badgeBuilder]/[labelBuilder] so a future hotel Michelin
/// Keys timeline can reuse this widget outright — only the badge (Keys
/// instead of stars) and label copy differ per award type, never the
/// timeline structure itself. Restaurant call sites pass a StarRow badge
/// builder and [michelinTransitionLabel].
class MichelinAwardTimeline extends StatelessWidget {
  final List<AwardTransition> transitions;
  final Widget Function(int value) badgeBuilder;
  final String Function(AwardTransition transition) labelBuilder;

  const MichelinAwardTimeline({
    super.key,
    required this.transitions,
    required this.badgeBuilder,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < transitions.length; i++)
          _TimelineRow(
            transition: transitions[i],
            badge: badgeBuilder(transitions[i].value),
            label: labelBuilder(transitions[i]),
            isLast: i == transitions.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final AwardTransition transition;
  final Widget badge;
  final String label;
  final bool isLast;

  const _TimelineRow({
    required this.transition,
    required this.badge,
    required this.label,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${transition.guideYear}',
              style: AppTypography.metadata.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  const Expanded(
                    child: VerticalDivider(
                      color: AppColors.divider,
                      thickness: 1,
                      width: 1,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
