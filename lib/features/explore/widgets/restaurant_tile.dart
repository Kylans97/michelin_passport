import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

class RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final bool isVisited;
  final bool isWishlisted;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onToggleWishlist;

  const RestaurantTile({
    super.key,
    required this.restaurant,
    this.isVisited = false,
    this.isWishlisted = false,
    this.onToggleVisited,
    this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(
            restaurant: restaurant,
            isVisited: isVisited,
            isWishlisted: isWishlisted,
            onToggleVisited: onToggleVisited,
            onToggleWishlist: onToggleWishlist,
          ),
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
            // Star count circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldMuted,
                border: Border.all(color: AppColors.goldBorder40, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '${restaurant.michelinStars}★',
                style: GoogleFonts.inter(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                  const SizedBox(height: 3),
                  Text(
                    restaurant.cuisine,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StarRow(count: restaurant.michelinStars, size: 12),
                      const SizedBox(width: 8),
                      Text(
                        '${restaurant.countryFlag}  ${restaurant.city}',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action icons — stopPropagation via separate GestureDetectors
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleWishlist,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isWishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isWishlisted
                          ? AppColors.gold
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleVisited,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isVisited
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isVisited
                          ? AppColors.gold
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
