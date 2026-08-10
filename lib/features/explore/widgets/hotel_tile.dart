import 'package:flutter/material.dart';
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

  const HotelTile({super.key, required this.hotel});

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
                      KeyRow(count: hotel.michelinKeys, size: 11),
                      const SizedBox(width: 8),
                      if (locationLabel.isNotEmpty)
                        Text(locationLabel, style: AppTypography.metadata),
                    ],
                  ),
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
