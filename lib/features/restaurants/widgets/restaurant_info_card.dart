import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/restaurant.dart';
import 'detail_section.dart';

class RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;

  // Non-null only when the hotel row should be tappable — i.e. the
  // restaurant is linked to an actual Michelin Key hotel (hotelId
  // non-null), not just carrying a property_name display fallback.
  final VoidCallback? onTapHotel;
  final bool hotelLoading;

  const RestaurantInfoCard({
    super.key,
    required this.restaurant,
    required this.hasHotelBadge,
    this.onTapHotel,
    this.hotelLoading = false,
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
      if (hasHotelBadge)
        _InfoRow(
          Icons.hotel_rounded,
          restaurant.hotelName!,
          onTap: onTapHotel,
          loading: hotelLoading,
        ),
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
  final VoidCallback? onTap;
  final bool loading;
  const _InfoRow(this.icon, this.text, {this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final row = Row(
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
        if (onTap != null) ...[
          const SizedBox(width: 8),
          loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: AppColors.textSecondary,
                    strokeWidth: 1.5,
                  ),
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
        ],
      ],
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}
