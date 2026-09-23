import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../constants/app_colors.dart';
import '../utils/venue_lifecycle.dart';

/// The list-tile lifecycle indicator — same "icon + one line of text"
/// shape RestaurantTile/HotelTile already use for their hotel-link and
/// World's 50 Best rows (see those files), not a new visual language.
/// Renders nothing for [VenueLifecycleState.normal].
class VenueLifecycleLine extends StatelessWidget {
  final VenueLifecycleState state;

  const VenueLifecycleLine({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final String? label;
    final Color color;
    switch (state) {
      case VenueLifecycleState.normal:
        return const SizedBox.shrink();
      case VenueLifecycleState.popupEnded:
        label = 'Pop-up ended';
        color = AppColors.taupe;
      case VenueLifecycleState.temporarilyClosed:
        label = 'Temporarily closed';
        color = AppColors.error;
      case VenueLifecycleState.permanentlyClosed:
        label = 'Permanently closed';
        color = AppColors.error;
    }

    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.metadata.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
