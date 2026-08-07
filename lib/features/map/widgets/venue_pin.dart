import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/passport_venue.dart';

/// Small circular map badge for one venue. Restaurant and hotel pins use
/// different icons (matching the icon vocabulary already used for these
/// venue types elsewhere — see PassportScreen's `_placesStat`) so the two
/// types stay visually distinguishable at a glance, without giant markers.
class VenuePin extends StatelessWidget {
  static const double size = 34;

  final PassportVenue venue;
  final VoidCallback onTap;

  const VenuePin({super.key, required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (venue) {
      RestaurantVenue() => Icons.restaurant_rounded,
      HotelVenue() => Icons.vpn_key_rounded,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.gold, size: 17),
      ),
    );
  }
}
