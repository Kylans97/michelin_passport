import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/toggle_action_button.dart';

/// "Add Stay" plus the Wishlist toggle for Hotel Detail. Unlike the
/// visited toggle on Restaurant Detail, "Add Stay" is never itself a
/// two-state toggle — a hotel can be stayed at many times, so every tap
/// opens Add Stay for a brand new historical row. Wishlist is the one real
/// toggle here, mirroring RestaurantActions'.
class HotelActions extends StatelessWidget {
  final bool isAuthenticated;
  final bool loadingPersonalState;
  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapAddStay;
  final VoidCallback onTapWishlist;

  const HotelActions({
    super.key,
    required this.isAuthenticated,
    required this.loadingPersonalState,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapAddStay,
    required this.onTapWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryButton(
          icon: Icons.add_circle_outline_rounded,
          label: 'Add Stay',
          onTap: onTapAddStay,
        ),
        const SizedBox(height: 10),
        if (isAuthenticated && loadingPersonalState)
          const ToggleActionButtonsLoadingRow(count: 1)
        else
          ToggleActionButton(
            icon: Icons.favorite_rounded,
            inactiveIcon: Icons.favorite_border_rounded,
            label: isWishlisted ? 'Wishlisted' : 'Wishlist',
            active: isWishlisted,
            enabled: isAuthenticated,
            saving: wishlistSaving,
            onTap: onTapWishlist,
          ),
      ],
    );
  }
}
