import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../passport_view_model.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

// "City, 🇬🇧 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Hotel hotel) {
  final country = hotel.flagEmoji.isNotEmpty
      ? '${hotel.flagEmoji} ${hotel.countryName}'
      : hotel.countryName;
  return '${hotel.cityName}, $country';
}

/// One unique hotel in the Passport list, scoped to the active
/// venue-type/year filter: stay count, latest stay and average rating all
/// reflect only the stays [stats] was built from. Tapping opens the
/// existing HotelDetailScreen, exactly as before — only the visual
/// presentation (now built on [CsPlaceCard]) changed. KeyRow is reused
/// unchanged (gold-filled keys) — see PassportRestaurantCard's matching
/// note on StarRow.
class PassportHotelCard extends StatelessWidget {
  final Hotel hotel;
  final PassportVenueStats stats;

  const PassportHotelCard({
    super.key,
    required this.hotel,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return CsPlaceCard(
      image: const CsImagePlaceholder(
        borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
      ),
      title: hotel.name,
      subtitle: _locationLabel(hotel),
      awardRow: hotel.hasMichelinKeys
          ? KeyRow(count: hotel.michelinKeys!, size: 14)
          : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // See PassportRestaurantCard's matching note: a single Text.rich
          // rather than a Row of separate Text widgets, so overflow can
          // never happen regardless of which font metrics actually render.
          Text.rich(
            TextSpan(
              children: [
                if (avg != null)
                  TextSpan(
                    text: '${avg.toStringAsFixed(1)} · ',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.mutedBrassOnLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(
                  text: stats.visitCount == 1
                      ? '1 stay'
                      : '${stats.visitCount} stays',
                  style: CsTypography.metadata,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Last stay ${_formatDate(stats.latestVisit)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.metadata,
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
      ),
    );
  }
}
