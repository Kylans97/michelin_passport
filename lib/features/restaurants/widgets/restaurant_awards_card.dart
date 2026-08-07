import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/restaurant.dart';
import 'detail_section.dart';

class RestaurantAwardsCard extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantAwardsCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final rows = <_AwardRow>[
      if (restaurant.hasMichelinStar)
        _AwardRow(
          icon: Icons.star_rounded,
          label: 'Michelin Stars',
          value:
              '${restaurant.michelinStars} Star${restaurant.michelinStars == 1 ? '' : 's'}',
        ),
      if (restaurant.isWorlds50Best)
        _AwardRow(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best",
          value: '#${restaurant.worlds50BestRank}',
        ),
      if (restaurant.isHallOfFame)
        const _AwardRow(
          icon: Icons.military_tech_rounded,
          label: 'Hall of Fame',
          value: 'Best of the Best',
        ),
    ];

    // Every catalogued restaurant qualifies on at least one of the above by
    // construction, but stay defensive rather than assume.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('AWARDS'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AwardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AwardRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.gold, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.inter(
          color: AppColors.gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
