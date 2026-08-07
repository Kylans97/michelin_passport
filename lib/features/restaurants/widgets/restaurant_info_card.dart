import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/restaurant.dart';
import 'detail_section.dart';

class RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;
  const RestaurantInfoCard({
    super.key,
    required this.restaurant,
    required this.hasHotelBadge,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(Icons.location_city_rounded, restaurant.cityName),
      _InfoRow(
        Icons.public_rounded,
        '${restaurant.flagEmoji}  ${restaurant.countryName}'.trim(),
      ),
      if (restaurant.address.isNotEmpty)
        _InfoRow(Icons.map_outlined, restaurant.address),
      if (hasHotelBadge) _InfoRow(Icons.hotel_rounded, restaurant.hotelName!),
    ];

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.textSecondary, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}
