import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/restaurant.dart';

/// The restaurant's address and (Restaurant Enrichment Step 1D) phone, as
/// an editorial "PRACTICAL INFORMATION" section (renamed from "LOCATION"
/// now that it holds more than just the address — UI Consistency Step 1B
/// originally turned the previous orphan icon+address row into a proper
/// labeled section, matching every other section on the screen). City/
/// country stays a single line under the hero, never repeated here.
///
/// Deliberately does NOT restate Website/Directions/Michelin Guide as text
/// — those are already the tappable actions in [VenueUtilityActions]
/// higher up the same screen; showing them again here as plain text would
/// be exactly the "visual duplication of information already presented
/// elsewhere" the practical-information brief warns against. Phone is
/// different: [VenueUtilityActions]'s Call action is icon+label only (no
/// room to show the actual number), so the number itself has no other home
/// on the screen.
class RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantInfoCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    if (restaurant.address.isEmpty) return const SizedBox.shrink();
    final phone = restaurant.phone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRACTICAL INFORMATION',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          restaurant.address,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        if (hasPhone) ...[
          const SizedBox(height: CsSpacing.xs),
          Text(
            phone,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ],
      ],
    );
  }
}
