import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';

/// One wishlisted venue — restaurant or hotel, rendered from the shared
/// [PassportVenue] abstraction so All/Restaurants/Hotels is a single list,
/// never two parallel card types. Tapping the card opens the venue's
/// existing Detail screen (via [onTap]); "Plan visit"/"Plan stay" is a
/// restrained secondary action, never automatic.
class WishlistCard extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onTap;
  final VoidCallback onPlan;
  final VoidCallback? onRemove;

  const WishlistCard({
    super.key,
    required this.venue,
    required this.onTap,
    required this.onPlan,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final (awardBadge, location, planLabel) = switch (v) {
      RestaurantVenue(:final restaurant) => (
        restaurant.hasMichelinStar
            ? StarRow(count: restaurant.michelinStars!)
            : null,
        '${restaurant.flagEmoji}  ${restaurant.cityName}, '
            '${restaurant.countryName}',
        'Plan visit',
      ),
      HotelVenue(:final hotel) => (
        KeyRow(count: hotel.michelinKeys),
        '${hotel.flagEmoji}  ${hotel.cityName}, ${hotel.countryName}',
        'Plan stay',
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (awardBadge != null) ...[
                          const SizedBox(height: 6),
                          awardBadge,
                        ],
                        const SizedBox(height: 6),
                        Text(
                          location,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRemove != null)
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
              const SizedBox(height: 10),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPlan,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            planLabel,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
