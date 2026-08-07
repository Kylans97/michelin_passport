import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// Restaurants linked to this hotel (resolved via
/// HotelRepository.getLinkedRestaurants, off restaurants_full's hotel_id).
/// Each row opens the existing RestaurantDetailScreen — no separate
/// hotel-restaurant detail screen.
class HotelRestaurantsCard extends StatelessWidget {
  final Future<List<Restaurant>> future;
  const HotelRestaurantsCard({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          );
        }
        final restaurants = snap.data ?? [];
        if (restaurants.isEmpty) {
          return Text(
            'Could not load linked restaurants.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < restaurants.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _LinkedRestaurantRow(restaurant: restaurants[i]),
            ],
          ],
        );
      },
    );
  }
}

class _LinkedRestaurantRow extends StatelessWidget {
  final Restaurant restaurant;
  const _LinkedRestaurantRow({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (restaurant.hasMichelinStar) ...[
                      const SizedBox(height: 4),
                      StarRow(count: restaurant.michelinStars!, size: 11),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
