import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';

class WishlistCard extends StatelessWidget {
  final Restaurant restaurant;
  final int rank;
  final VoidCallback? onRemove;

  const WishlistCard({
    super.key,
    required this.restaurant,
    required this.rank,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.goldBorder50,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // restaurants_full has no cuisine display column, so that
                // line is omitted here (compatibility fix, not a redesign).
                if (restaurant.hasMichelinStar)
                  StarRow(count: restaurant.michelinStars!),
                const SizedBox(height: 3),
                Text(
                  '${restaurant.flagEmoji}  ${restaurant.cityName}, ${restaurant.countryName}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.gold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
