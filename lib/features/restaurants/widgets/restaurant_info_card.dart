import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/restaurant.dart';

/// The restaurant's address, as an editorial "LOCATION" section (UI
/// Consistency Step 1B — physical-device polish: the previous orphan
/// icon+address row is now a proper labeled section, matching every other
/// section on the screen, rather than a loose trailing line). City/country
/// stays a single line under the hero, never repeated here — this is
/// address alone.
class RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantInfoCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    if (restaurant.address.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCATION',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          restaurant.address,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ],
    );
  }
}
