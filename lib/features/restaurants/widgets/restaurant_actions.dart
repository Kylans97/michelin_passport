import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/toggle_action_button.dart';

/// The two personal-state toggles (visited / wishlist), plus the external
/// links (Maps, Michelin Guide, Website) as a single row of compact,
/// equally-weighted utility buttons — none of them competes with the
/// venue content around it.
class RestaurantActions extends StatelessWidget {
  final bool isAuthenticated;
  final bool loadingPersonalState;
  final bool isVisited;
  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapVisited;
  final VoidCallback onTapWishlist;
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenMichelin;
  final VoidCallback? onOpenWebsite;

  const RestaurantActions({
    super.key,
    required this.isAuthenticated,
    required this.loadingPersonalState,
    required this.isVisited,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapVisited,
    required this.onTapWishlist,
    required this.onOpenMaps,
    required this.onOpenMichelin,
    required this.onOpenWebsite,
  });

  @override
  Widget build(BuildContext context) {
    final hasMichelin = onOpenMichelin != null;
    final hasWebsite = onOpenWebsite != null;

    return Column(
      children: [
        if (isAuthenticated && loadingPersonalState)
          const ToggleActionButtonsLoadingRow()
        else
          Row(
            children: [
              Expanded(
                child: ToggleActionButton(
                  icon: Icons.check_circle_rounded,
                  inactiveIcon: Icons.check_circle_outline_rounded,
                  label: isVisited ? 'Add another visit' : 'Mark as visited',
                  active: isVisited,
                  enabled: isAuthenticated,
                  onTap: onTapVisited,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ToggleActionButton(
                  icon: Icons.favorite_rounded,
                  inactiveIcon: Icons.favorite_border_rounded,
                  label: isWishlisted ? 'Wishlisted' : 'Wishlist',
                  active: isWishlisted,
                  enabled: isAuthenticated,
                  saving: wishlistSaving,
                  onTap: onTapWishlist,
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                icon: Icons.map_outlined,
                label: 'Maps',
                onTap: onOpenMaps,
              ),
            ),
            if (hasMichelin) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'Michelin',
                  onTap: onOpenMichelin!,
                ),
              ),
            ],
            if (hasWebsite) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  onTap: onOpenWebsite!,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
