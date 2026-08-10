import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/hotel.dart';
import '../../restaurants/widgets/detail_section.dart';

/// Current MICHELIN Guide / World's 50 Best Hotels status — the hotel
/// counterpart of RestaurantAwardsCard. A hotel with no confirmed Key value
/// simply omits that row rather than showing "0 Keys" or "Unrated"; a hotel
/// with neither a Key nor a current World's 50 Best rank renders nothing at
/// all (SizedBox.shrink), the same defensive-but-currently-unreachable
/// guard RestaurantAwardsCard already has.
class HotelAwardsCard extends StatelessWidget {
  final Hotel hotel;
  const HotelAwardsCard({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    final rows = <_AwardRow>[
      if (hotel.hasMichelinKeys)
        _AwardRow(
          icon: Icons.vpn_key_rounded,
          label: 'MICHELIN Keys',
          value:
              '${hotel.michelinKeys} Key${hotel.michelinKeys == 1 ? '' : 's'}',
        ),
      if (hotel.isWorlds50Best)
        _AwardRow(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best Hotels",
          value: hotel.worlds50BestYear != null
              ? '#${hotel.worlds50BestRank} · ${hotel.worlds50BestYear}'
              : '#${hotel.worlds50BestRank}',
        ),
    ];

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
