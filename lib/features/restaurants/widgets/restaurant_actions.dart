import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The two personal-state toggles (visited / wishlist) plus the external
/// links (Maps, Michelin Guide, Website), styled as a single coherent block
/// of "premium actions" rather than a stack of generic buttons.
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
          const _TogglesLoadingRow()
        else
          Row(
            children: [
              Expanded(
                child: _ToggleButton(
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
                child: _ToggleButton(
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
        const SizedBox(height: 14),
        _LinkButton(
          icon: Icons.map_rounded,
          label: 'Google Maps',
          filled: true,
          onTap: onOpenMaps,
        ),
        if (hasMichelin || hasWebsite) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasMichelin)
                Expanded(
                  child: _LinkButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Michelin Guide',
                    filled: false,
                    onTap: onOpenMichelin!,
                  ),
                ),
              if (hasMichelin && hasWebsite) const SizedBox(width: 10),
              if (hasWebsite)
                Expanded(
                  child: _LinkButton(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    filled: false,
                    onTap: onOpenWebsite!,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// Placeholder shown for the width of a heartbeat while personal state loads,
// so the two action buttons don't flash from "not yet" to their real state.
class _TogglesLoadingRow extends StatelessWidget {
  const _TogglesLoadingRow();

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(2, (i) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i == 0 ? 10 : 0),
          child: Container(
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: AppColors.textSecondary,
                strokeWidth: 1.5,
              ),
            ),
          ),
        ),
      );
    }),
  );
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    this.enabled = true,
    this.saving = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Tapping while "disabled" (signed out) still fires onTap, which shows
    // the sign-in message — see AUTH SAFETY. Only a saving in-flight tap is
    // truly ignored.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: active ? AppColors.goldMuted : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppColors.goldBorder60 : AppColors.cardBorder,
              width: active ? 1.0 : 0.5,
            ),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: saving
                      ? const SizedBox(
                          key: ValueKey('saving'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          active ? icon : inactiveIcon,
                          key: ValueKey(active),
                          color: active
                              ? AppColors.gold
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: active ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: filled ? 54 : 50,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }
}
