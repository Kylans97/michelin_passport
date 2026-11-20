import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/journey.dart';
import '../journey_visuals.dart';

/// One mark per cabin the journey's text counts: a carriage window on a
/// train, a porthole on a ship. Grouped by cabin type when the text names
/// the types ("Suites (16)"). The marks are a count, nothing more: no
/// carriage or deck layout is implied.
class JourneyCabins extends StatelessWidget {
  final CabinLayout layout;
  final JourneyKind kind;

  const JourneyCabins({super.key, required this.layout, required this.kind});

  @override
  Widget build(BuildContext context) {
    // Smaller marks once there are many, so a 149-suite ship stays a
    // texture rather than a wall.
    final compact = layout.total > 60;
    final named = layout.groups.any((g) => g.name != null);
    return Semantics(
      label: [
        for (final g in layout.groups)
          g.name == null ? '${g.count}' : '${g.name}: ${g.count}',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < layout.groups.length; i++) ...[
            if (i > 0) const SizedBox(height: CsSpacing.base),
            if (named) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      layout.groups[i].name ?? '',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${layout.groups[i].count}',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CsSpacing.sm),
            ],
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                for (var c = 0; c < layout.groups[i].count; c++)
                  _CabinMark(kind: kind, compact: compact),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CabinMark extends StatelessWidget {
  final JourneyKind kind;
  final bool compact;

  const _CabinMark({required this.kind, required this.compact});

  @override
  Widget build(BuildContext context) {
    final isShip = kind == JourneyKind.ship;
    final width = isShip ? (compact ? 10.0 : 14.0) : (compact ? 9.0 : 12.0);
    final height = isShip ? width : (compact ? 12.0 : 15.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        shape: isShip ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isShip
            ? null
            : const BorderRadius.vertical(
                top: Radius.circular(3),
                bottom: Radius.circular(1.5),
              ),
        border: Border.all(
          color: AppColors.forestGreen,
          width: isShip ? 1.4 : 1,
        ),
      ),
    );
  }
}
