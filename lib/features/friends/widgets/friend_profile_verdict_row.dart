import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit;
import 'friend_profile_widgets.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// One row in `[64pt photo | text | score]` — the Overview tab's
/// "{NAME}'S VERDICTS" preview and its own "All →" full list share this
/// exact widget, so the two can never drift out of visual sync.
class FriendVerdictRow extends StatelessWidget {
  final FriendVenueVisit visit;
  final String? photoUrl;
  final VoidCallback onTap;

  const FriendVerdictRow({
    super.key,
    required this.visit,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHotel = visit.venue is HotelVenue;
    final date = visit.visit.visitedOn;
    final typeLabel = '${isHotel ? 'HOTEL' : 'RESTAURANT'} · '
        '${date.day} ${_months[date.month - 1]}';

    final starsAward = !isHotel && (visit.stars ?? 0) > 0
        ? CsEditorialStarRow(count: visit.stars!, size: 13)
        : null;
    final keysAward = isHotel && (visit.keys ?? 0) > 0
        ? CsEditorialKeyRow(count: visit.keys!, size: 13)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.hairlineOnGreen),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhotoOrTile(
                    photoUrl: photoUrl,
                    venueName: visit.venue.name,
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(width: CsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: CsTypography.editorialLabel().copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                visit.venue.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CsTypography.editorialTitle(size: 22).copyWith(
                                  color: AppColors.textOnDark,
                                ),
                              ),
                            ),
                            if (starsAward != null) ...[
                              const SizedBox(width: 6),
                              starsAward,
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: CsCountryLabel(
                                cityName: visit.cityName,
                                countryCode: visit.venue.countryCode,
                                style: CsTypography.editorialBody.copyWith(
                                  color: AppColors.secondaryOnDark,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (keysAward != null) ...[
                              const SizedBox(width: 6),
                              keysAward,
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (visit.score != null) ...[
                    const SizedBox(width: CsSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${visit.score}',
                          style: CsTypography.editorialTitle(size: 40).copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        Text(
                          '/10',
                          style: CsTypography.editorialTitle(
                            size: 15,
                            italic: true,
                          ).copyWith(color: AppColors.secondaryOnDark),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
