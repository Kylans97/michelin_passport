import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';

class RestaurantHero extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;
  const RestaurantHero({
    super.key,
    required this.restaurant,
    required this.hasHotelBadge,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (restaurant.isWorlds50Best)
        _HeroBadge(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best · #${restaurant.worlds50BestRank}",
        ),
      if (hasHotelBadge)
        _HeroBadge(icon: Icons.hotel_rounded, label: restaurant.hotelName!),
    ];

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.background,
      title: Text(
        restaurant.name,
        style: GoogleFonts.playfairDisplay(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1C1400),
                Color(0xFF110E00),
                AppColors.background,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (restaurant.hasMichelinStar)
                    StarRow(count: restaurant.michelinStars!, size: 18),
                  if (badges.isNotEmpty) ...[
                    SizedBox(height: restaurant.hasMichelinStar ? 10 : 0),
                    Wrap(spacing: 8, runSpacing: 8, children: badges),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    restaurant.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.goldAlpha10,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.goldBorder40, width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
