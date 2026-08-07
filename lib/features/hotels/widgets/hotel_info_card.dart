import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/hotel.dart';
import '../../restaurants/widgets/detail_section.dart';

class HotelInfoCard extends StatelessWidget {
  final Hotel hotel;
  const HotelInfoCard({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(Icons.location_city_rounded, hotel.cityName),
      _InfoRow(
        Icons.public_rounded,
        '${hotel.flagEmoji}  ${hotel.countryName}'.trim(),
      ),
      if (hotel.address.isNotEmpty) _InfoRow(Icons.map_outlined, hotel.address),
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
