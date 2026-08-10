import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/hotel.dart';
import '../../hotels/hotel_detail_screen.dart';

// A discovery card, not a database row — mirrors RestaurantTile's
// photo-ready thumbnail + folded-in award treatment.
class HotelTile extends StatelessWidget {
  final Hotel hotel;

  // Only relevant while the Explore World's 50 Best filter is active — see
  // RestaurantTile.showWorlds50BestRank. Unlike that restaurant version,
  // the rank line here is shown regardless of whether the hotel also holds
  // a Key: a Key-less World's 50 Best hotel must remain just as
  // discoverable and its recognition just as visible as a Key-holding one.
  final bool showWorlds50BestRank;

  const HotelTile({
    super.key,
    required this.hotel,
    this.showWorlds50BestRank = false,
  });

  String get _locationLabel {
    final parts = <String>[
      if (hotel.flagEmoji.isNotEmpty) hotel.flagEmoji,
      if (hotel.cityName.isNotEmpty) hotel.cityName,
    ];
    return parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = _locationLabel;
    final showRankLine = showWorlds50BestRank && hotel.isWorlds50Best;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
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
                    hotel.name,
                    style: AppTypography.editorialHeading.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hotel.hasMichelinKeys) ...[
                        KeyRow(count: hotel.michelinKeys!, size: 11),
                        const SizedBox(width: 8),
                      ],
                      if (locationLabel.isNotEmpty)
                        Expanded(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metadata,
                          ),
                        ),
                    ],
                  ),
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
                        Expanded(
                          child: Text(
                            "#${hotel.worlds50BestRank} · World's 50 Best",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hotel.hasMichelinRestaurant) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.restaurantCount == 1
                                ? '1 Michelin restaurant'
                                : '${hotel.restaurantCount} Michelin restaurants',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
