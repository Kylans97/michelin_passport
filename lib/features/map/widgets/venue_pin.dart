import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/map_pin.dart';

/// Small circular map badge for one pin. Restaurant/Hotel/Event pins each
/// use a different icon (matching the icon vocabulary already used for
/// Restaurant/Hotel elsewhere — see PassportScreen's `_placesStat` — plus a
/// calendar icon added for Events V2 Step 5) so all three types stay
/// visually distinguishable at a glance without a legend or a differently
/// shaped marker — deepGreen fill, ivory border/icon throughout, no gold.
class VenuePin extends StatelessWidget {
  static const double size = 34;

  final MapPinType type;
  final VoidCallback onTap;

  const VenuePin({super.key, required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      MapPinType.restaurant => Icons.restaurant_rounded,
      MapPinType.hotel => Icons.vpn_key_rounded,
      MapPinType.event => Icons.event_rounded,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.deepGreen,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ivory, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.ivory, size: 17),
      ),
    );
  }
}
