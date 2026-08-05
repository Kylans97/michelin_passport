import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

// Catalogue-read-only tile: no visited/wishlist actions yet — that is a
// later slice.
class RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantTile({super.key, required this.restaurant});

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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AwardBadge(restaurant: restaurant),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (restaurant.hasMichelinStar) ...[
                        StarRow(count: restaurant.michelinStars!, size: 12),
                        const SizedBox(width: 8),
                      ],
                      if (locationLabel.isNotEmpty)
                        Text(
                          locationLabel,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
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
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
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

// Star-count circle for a Michelin-starred restaurant, or a trophy/rank
// treatment for a restaurant whose current award is a World's 50 Best
// placement rather than a star — never "0★" and never an empty star row.
class _AwardBadge extends StatelessWidget {
  final Restaurant restaurant;
  const _AwardBadge({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.goldMuted,
        border: Border.all(color: AppColors.goldBorder40, width: 0.5),
      ),
      alignment: Alignment.center,
      child: restaurant.hasMichelinStar
          ? Text(
              '${restaurant.michelinStars}★',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            )
          : restaurant.isWorlds50Best
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  size: 14,
                ),
                Text(
                  '#${restaurant.worlds50BestRank}',
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : const Icon(
              Icons.restaurant_rounded,
              color: AppColors.gold,
              size: 18,
            ),
    );
  }
}
