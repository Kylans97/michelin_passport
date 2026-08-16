import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/hotel.dart';

/// The hotel's address, as an editorial "LOCATION" section — mirrors
/// [RestaurantInfoCard] (UI Consistency Step 1B). City/country stays a
/// single line under the hero rather than repeated here.
class HotelInfoCard extends StatelessWidget {
  final Hotel hotel;
  const HotelInfoCard({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    if (hotel.address.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCATION',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          hotel.address,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ],
    );
  }
}
