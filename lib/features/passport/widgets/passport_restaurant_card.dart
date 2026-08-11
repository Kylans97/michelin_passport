import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';
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

// "City, 🇳🇱 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Restaurant restaurant) {
  final country = restaurant.flagEmoji.isNotEmpty
      ? '${restaurant.flagEmoji} ${restaurant.countryName}'
      : restaurant.countryName;
  return '${restaurant.cityName}, $country';
}

/// One unique restaurant in the Passport list, scoped to the active
/// venue-type/year filter: visit count, latest visit and average rating
/// all reflect only the visits [stats] was built from. Tapping opens the
/// existing RestaurantDetailScreen, exactly as before — only the visual
/// presentation (now built on [CsPlaceCard]) changed. StarRow is reused
/// unchanged (gold-filled stars): it's a shared component read by every
/// other screen showing Michelin stars today, and gold-on-ivory is already
/// the established, working combination everywhere else in the app.
class PassportRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final PassportVenueStats stats;

  const PassportRestaurantCard({
    super.key,
    required this.restaurant,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return CsPlaceCard(
      image: const CsImagePlaceholder(
        borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
      ),
      title: restaurant.name,
      subtitle: _locationLabel(restaurant),
      awardRow: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 14)
          : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A single Text.rich rather than a Row of separate Text widgets
          // (one of which was Expanded): a Row can still overflow if its
          // NON-flexible siblings alone exceed the available width — which
          // this genuinely did once, since Inter's real glyph metrics
          // aren't guaranteed to be loaded (a slow/offline google_fonts
          // fetch falls back to a wider system font on a real device, the
          // same way flutter test's own font resolution does) — see the
          // RestaurantTile/HotelTile overflow fix this must not regress.
          // Text.rich's own maxLines/overflow handles this unconditionally,
          // regardless of which font actually ends up rendering.
          Text.rich(
            TextSpan(
              children: [
                if (avg != null)
                  TextSpan(
                    text: '${avg.toStringAsFixed(1)} average · ',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.mutedBrassOnLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(
                  text: stats.visitCount == 1
                      ? '1 visit'
                      : '${stats.visitCount} visits',
                  style: CsTypography.metadata,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Last visit ${_formatDate(stats.latestVisit)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.metadata,
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      ),
    );
  }
}
