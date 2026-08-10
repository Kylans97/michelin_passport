import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';

/// The two personal-state toggles (visited / wishlist), plus the external
/// links (Maps, Michelin Guide, Website) as a single row of compact,
/// equally-weighted utility buttons — none of them competes with the
/// venue content around it. Gold is reserved for the toggles' active
/// state only when tied to a real personal record (visited), never used
/// just to decorate a button.
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
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: const SizedBox(
              width: 14,
              height: 14,
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
    // Active uses a quiet brand-green tint, not gold — this is a personal
    // record, not an award/ranking, so gold stays reserved for those. See
    // RestaurantAwardsCard / CircularScoreBadge for where gold still
    // appears.
    final activeTint = AppColors.brandGreen.withValues(alpha: 0.08);
    final activeBorder = AppColors.brandGreen.withValues(alpha: 0.35);

    // Tapping while "disabled" (signed out) still fires onTap, which shows
    // the sign-in message — see AUTH SAFETY. Only a saving in-flight tap is
    // truly ignored.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? activeTint : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? activeBorder : AppColors.cardBorder,
              width: 0.5,
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
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.brandGreen,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          active ? icon : inactiveIcon,
                          key: ValueKey(active),
                          color: active
                              ? AppColors.brandGreen
                              : AppColors.textSecondary,
                          size: 19,
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: active
                        ? AppColors.brandGreen
                        : AppColors.textSecondary,
                    fontSize: 11,
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
