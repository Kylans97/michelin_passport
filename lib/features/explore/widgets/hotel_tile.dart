import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../hotels/hotel_detail_screen.dart';

// Catalogue-read-only tile: no hotel stay/wishlist actions yet — that is a
// later slice.
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KeysBadge(hotel: hotel),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      KeyRow(count: hotel.michelinKeys, size: 12),
                      const SizedBox(width: 8),
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

// Keys-count circle, deliberately distinct from RestaurantTile's star
// badge: a key glyph rather than a star, so the two venue types never look
// interchangeable at a glance.
class _KeysBadge extends StatelessWidget {
  final Hotel hotel;
  const _KeysBadge({required this.hotel});

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
      child: Text(
        '${hotel.michelinKeys}🔑',
        style: GoogleFonts.inter(
          color: AppColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
