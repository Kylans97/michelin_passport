import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/journey.dart';

/// The selected route stop by stop, as a vertical rail under the globe:
/// its name and length above, then every stop the operator's itinerary
/// names, in order, the first filled and marked Depart, the last marked
/// Arrive (Return on a round trip). Where the route crosses a border, a
/// stop carries its country when it differs from the stop before; a
/// route within one country names none. Only recorded stops are drawn,
/// never a place the train or ship merely passes.
class JourneyItinerary extends StatelessWidget {
  final JourneyRoute route;
  final List<JourneyRouteStop> stops;

  /// Country names by code, for the border labels. A code missing from
  /// the map shows as the code itself.
  final Map<String, String> countryNames;

  const JourneyItinerary({
    super.key,
    required this.route,
    required this.stops,
    this.countryNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final length = route.lengthLabel;
    final crossesBorders = stops.map((s) => s.countryCode).toSet().length > 1;
    final roundTrip = stops.length > 1 && stops.first.place == stops.last.place;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                route.name,
                style: CsTypography.sectionTitle.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            if (length != null) ...[
              const SizedBox(width: CsSpacing.md),
              Text(
                length.toUpperCase(),
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
            ],
          ],
        ),
        const SizedBox(height: CsSpacing.lg),
        for (var i = 0; i < stops.length; i++)
          _StopRow(
            place: stops[i].place,
            label: i == 0
                ? 'DEPART'
                : i == stops.length - 1
                ? (roundTrip ? 'RETURN' : 'ARRIVE')
                : null,
            country:
                crossesBorders &&
                    (i == 0 || stops[i - 1].countryCode != stops[i].countryCode)
                ? (countryNames[stops[i].countryCode] ?? stops[i].countryCode)
                      .toUpperCase()
                : null,
            first: i == 0,
            last: i == stops.length - 1,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final String place;
  final String? label;
  final String? country;
  final bool first;
  final bool last;

  const _StopRow({
    required this.place,
    required this.label,
    required this.country,
    required this.first,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final end = first || last;
    final dot = end ? 12.0 : 8.0;
    // The dot sits on the place name's first line, below the label when
    // there is one.
    final dotTop = label != null ? 21.0 : 7.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 1,
                  height: dotTop,
                  color: first ? Colors.transparent : AppColors.forestGreen,
                ),
                Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: first ? AppColors.forestGreen : AppColors.ivory,
                    border: Border.all(
                      color: AppColors.forestGreen,
                      width: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    color: last ? Colors.transparent : AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: CsSpacing.base),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : CsSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                        fontSize: 10,
                      ),
                    ),
                  Text(
                    place,
                    style: CsTypography.editorialLead(size: end ? 21 : 18)
                        .copyWith(
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.normal,
                        ),
                  ),
                  if (country != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        country!,
                        style: CsTypography.eyebrow.copyWith(
                          color: AppColors.taupe,
                          fontSize: 10,
                        ),
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
