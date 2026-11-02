import 'package:flutter/material.dart';
import '../../models/opening_hours.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// "OPENING HOURS" on a restaurant's page, as the restaurant itself keeps
/// them: one line per run of days with the same hours ("Tue – Sat"),
/// closed days included so the week reads whole. Times are the
/// restaurant's own, never converted to the viewer's clock. Under the
/// week, the closed days still to come ("Closed 24 – 26 Dec 2026"), at
/// most three. Nothing at all when the restaurant gave neither.
class VenueOpeningHoursSection extends StatelessWidget {
  final OpeningHours hours;
  final List<RestaurantClosure> closures;

  const VenueOpeningHoursSection({
    super.key,
    required this.hours,
    this.closures = const [],
  });

  static bool hasContent(
    OpeningHours hours,
    List<RestaurantClosure> closures,
  ) => !hours.isEmpty || closures.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasContent(hours, closures)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPENING HOURS',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        if (!hours.isEmpty)
          for (final line in hours.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      line.daysLabel,
                      style: CsTypography.body.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.hoursLabel,
                      style: CsTypography.body.copyWith(
                        color: line.ranges.isEmpty
                            ? AppColors.taupe
                            : AppColors.forestGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (closures.isNotEmpty) ...[
          if (!hours.isEmpty) const SizedBox(height: CsSpacing.sm),
          for (final closure in closures.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'Closed ${closure.label}',
                style: CsTypography.body.copyWith(color: AppColors.taupe),
              ),
            ),
        ],
      ],
    );
  }
}
