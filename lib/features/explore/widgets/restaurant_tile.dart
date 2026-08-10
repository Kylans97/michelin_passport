import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

// A discovery card, not a database row: a photo-ready thumbnail leads,
// with the award context folded into the text content rather than a
// dominant gold badge circle. See VenueThumbnail for the photography hook.
class RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;

  // Only relevant while the Explore World's 50 Best filter is active. The
  // rank already shows for a non-starred restaurant via the award line;
  // this only fills the gap for a starred restaurant that's *also*
  // World's 50 Best ranked. Never duplicates what's already shown.
  final bool showWorlds50BestRank;

  const RestaurantTile({
    super.key,
    required this.restaurant,
    this.showWorlds50BestRank = false,
  });

  String get _locationLabel {
    final parts = <String>[
      if (restaurant.flagEmoji.isNotEmpty) restaurant.flagEmoji,
      if (restaurant.cityName.isNotEmpty) restaurant.cityName,
    ];
    return parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = _locationLabel;
    final hasHotel =
        restaurant.isInHotel && (restaurant.hotelName?.isNotEmpty ?? false);
    final showRankLine =
        showWorlds50BestRank &&
        restaurant.isWorlds50Best &&
        restaurant.hasMichelinStar;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VenueThumbnail(imageUrl: null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppTypography.editorialHeading.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (restaurant.hasMichelinStar) ...[
                        StarRow(count: restaurant.michelinStars!, size: 11),
                        const SizedBox(width: 8),
                      ],
                      if (locationLabel.isNotEmpty)
                        Text(locationLabel, style: AppTypography.metadata),
                    ],
                  ),
                  if (hasHotel) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.hotel_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant.hotelName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metadata.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (showRankLine) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 12,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "#${restaurant.worlds50BestRank} · World's 50 Best",
                          style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
